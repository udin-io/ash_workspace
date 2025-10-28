if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshWorkspace.Install do
    @moduledoc """
    Installs AshWorkspace resources, migrations, and configuration.

    Should be run with `mix igniter.install ash_workspace`

    This will:
    - Generate Workspace, WorkspaceUser, and Invitation resources
    - Create database migrations and snapshots
    - Add configuration to config/config.exs

    ## Options

        --domain    - The domain module (default: auto-detected)
        --repo      - The repo module (default: auto-detected)
        --yes       - Skip all prompts and use defaults
        --migrate   - Run migrations after generating them (default: false)
    """

    @shortdoc @moduledoc
    use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _parent) do
    %Igniter.Mix.Task.Info{
      group: :ash_workspace,
      example: "mix ash_workspace.install",
      positional: [],
      schema: [
        domain: :string,
        repo: :string,
        yes: :boolean,
        migrate: :boolean
      ],
      aliases: [
        y: :yes,
        m: :migrate
      ]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    options = igniter.args.options

    igniter
    |> detect_or_prompt_domain(options)
    |> detect_or_prompt_repo(options)
    |> generate_workspace_resource()
    |> generate_workspace_user_resource()
    |> generate_invitation_resource()
    |> update_domain_module()
    |> update_user_resource()
    |> generate_ui_components()
    |> generate_liveview_files()
    |> generate_controller_files()
    |> generate_helper_modules()
    |> update_router()
    # TODO: Comment out manual migration generation - let Ash handle it
    # |> generate_migrations()
    |> add_configuration()
    |> print_success_message()
    |> run_ash_codegen()
  end

  defp detect_or_prompt_domain(igniter, options) do
    domain_module =
      case options[:domain] do
        nil ->
          # Use Igniter's built-in module naming which prompts if needed
          Igniter.Project.Module.module_name(igniter, "Accounts")

        domain ->
          Igniter.Project.Module.parse(domain)
      end

    Igniter.assign(igniter, :domain_module, domain_module)
  end

  defp detect_or_prompt_repo(igniter, options) do
    repo_module =
      case options[:repo] do
        nil ->
          # Use Igniter's built-in module naming which prompts if needed
          Igniter.Project.Module.module_name(igniter, "Repo")

        repo ->
          Igniter.Project.Module.parse(repo)
      end

    Igniter.assign(igniter, :repo_module, repo_module)
  end

  defp generate_workspace_resource(igniter) do
    domain_module = igniter.assigns.domain_module
    repo_module = igniter.assigns.repo_module
    otp_app = Igniter.Project.Application.app_name(igniter)

    workspace_module = Module.concat([domain_module, Workspace])
    workspace_user_module = Module.concat([domain_module, WorkspaceUser])
    invitation_module = Module.concat([domain_module, Invitation])
    user_module = Module.concat([domain_module, User])

    code = """
    use Ash.Resource,
      otp_app: #{inspect(otp_app)},
      domain: #{inspect(domain_module)},
      data_layer: AshPostgres.DataLayer

    postgres do
      table "workspaces"
      repo #{inspect(repo_module)}
    end

    actions do
      defaults [:read, :destroy, create: [:name], update: [:name]]
    end

    attributes do
      uuid_primary_key :id

      attribute :name, :string do
        allow_nil? false
        public? true
      end

      timestamps()
    end

    relationships do
      has_many :workspace_users, #{inspect(workspace_user_module)}
      has_many :invitations, #{inspect(invitation_module)}

      many_to_many :users, #{inspect(user_module)} do
        through #{inspect(workspace_user_module)}
      end
    end

    code_interface do
      define :get_workspace_by_id, get_by: [:id], action: :read
    end
    """

    file_path = workspace_module |> Module.split() |> Enum.map(&Macro.underscore/1) |> Path.join()
    file_path = "lib/#{file_path}.ex"

    igniter
    |> Igniter.Project.Module.create_module(workspace_module, code)
    |> Igniter.assign(:workspace_module, workspace_module)
  end

  defp generate_workspace_user_resource(igniter) do
    domain_module = igniter.assigns.domain_module
    repo_module = igniter.assigns.repo_module
    otp_app = Igniter.Project.Application.app_name(igniter)

    workspace_module = Module.concat([domain_module, Workspace])
    workspace_user_module = Module.concat([domain_module, WorkspaceUser])
    user_module = Module.concat([domain_module, User])

    code = """
    use Ash.Resource,
      otp_app: #{inspect(otp_app)},
      domain: #{inspect(domain_module)},
      data_layer: AshPostgres.DataLayer

    postgres do
      table "workspaces_users"
      repo #{inspect(repo_module)}
    end

    actions do
      defaults [
        :read,
        :destroy,
        create: [:role, :workspace_id, :user_id],
        update: [:role]
      ]

      read :get_workspace_users_by_workspace_id do
        description "Get workspace users by workspace ID."
        argument :workspace_id, :uuid, allow_nil?: false
        filter expr(workspace_id == ^arg(:workspace_id))
      end
    end

    attributes do
      uuid_primary_key :id

      attribute :role, :atom do
        allow_nil? false
        public? true
        default :member
        constraints one_of: [:admin, :member, :billing]
      end

      timestamps()
    end

    relationships do
      belongs_to :workspace, #{inspect(workspace_module)} do
        allow_nil? false
        attribute_writable? true
      end

      belongs_to :user, #{inspect(user_module)} do
        allow_nil? false
        attribute_writable? true
      end
    end

    code_interface do
      define :get_workspace_users_by_workspace_id,
        action: :get_workspace_users_by_workspace_id,
        args: [:workspace_id]
    end
    """

    igniter
    |> Igniter.Project.Module.create_module(workspace_user_module, code)
    |> Igniter.assign(:workspace_user_module, workspace_user_module)
  end

  defp generate_invitation_resource(igniter) do
    domain_module = igniter.assigns.domain_module
    repo_module = igniter.assigns.repo_module
    otp_app = Igniter.Project.Application.app_name(igniter)

    workspace_module = Module.concat([domain_module, Workspace])
    user_module = Module.concat([domain_module, User])
    invitation_module = Module.concat([domain_module, Invitation])

    code = """
    use Ash.Resource,
      otp_app: #{inspect(otp_app)},
      domain: #{inspect(domain_module)},
      authorizers: [Ash.Policy.Authorizer],
      data_layer: AshPostgres.DataLayer

    @days_to_expire 7

    postgres do
      table "invitations"
      repo #{inspect(repo_module)}
    end

    actions do
      defaults [:read, :destroy]

      create :create do
        accept [:email, :role, :workspace_id, :user_id]

        change AshWorkspace.Changes.SetToken
        validate AshWorkspace.Validators.EmailUniquenessInWorkspace

        change after_action(&AshWorkspace.Hooks.SendInvitationEmail.after_action/3)
      end

      update :resend_invitation do
        require_atomic? false

        change AshWorkspace.Changes.SetToken

        change after_action(&AshWorkspace.Hooks.SendInvitationEmail.after_action/3)
      end

      read :get_pending_by_email do
        description "Get pending invitation by email."
        get? true
        argument :email, :string, allow_nil?: false

        filter expr(
                 email == ^arg(:email) and
                   status == :created and
                   updated_at >= ago(@days_to_expire, "day")
               )
      end

      read :get_all_pending_invitations do
        description "Get all pending invitations."
        filter expr(
          status == :created and
            updated_at >= ago(@days_to_expire, "day")
        )
      end

      update :accept_invitation do
        description "Accept an invitation."
        change set_attribute(:status, :accepted)
      end

      update :revoke_invitation do
        description "Revoke an invitation."
        change set_attribute(:status, :revoked)
      end
    end

    policies do
      policy action([
               :create,
               :get_pending_by_email,
               :get_all_pending_invitations,
               :resend_invitation,
               :accept_invitation,
               :revoke_invitation,
               :read
             ]) do
        authorize_if always()
      end
    end

    validations do
      validate match(:email, ~r/^[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$/),
        message: "Invalid email format"
    end

    attributes do
      uuid_primary_key :id

      attribute :email, :ci_string do
        allow_nil? false
      end

      attribute :role, :atom do
        constraints one_of: [:member, :billing, :admin]
        allow_nil? false
      end

      attribute :token, :string do
        allow_nil? false
        sensitive? true
      end

      attribute :status, :atom do
        default :created
        constraints one_of: [:created, :accepted, :revoked]
        allow_nil? false
      end

      timestamps()
    end

    relationships do
      belongs_to :workspace, #{inspect(workspace_module)} do
        allow_nil? false
      end

      belongs_to :user, #{inspect(user_module)} do
        allow_nil? false
      end
    end

    code_interface do
      define :get_pending_invitations_by_email,
        action: :get_pending_by_email,
        args: [:email]
    end
    """

    igniter
    |> Igniter.Project.Module.create_module(invitation_module, code)
    |> Igniter.assign(:invitation_module, invitation_module)
  end

  defp update_domain_module(igniter) do
    workspace_module = igniter.assigns.workspace_module
    workspace_user_module = igniter.assigns.workspace_user_module
    invitation_module = igniter.assigns.invitation_module

    add_resources_to_domain(igniter, workspace_module, workspace_user_module, invitation_module)
  end

  defp add_resources_to_domain(igniter, workspace_module, workspace_user_module, invitation_module) do
    domain_module = igniter.assigns.domain_module

    Igniter.Project.Module.find_and_update_module!(igniter, domain_module, fn zipper ->
      # Navigate to the resources block
      with {:ok, zipper} <- Igniter.Code.Function.move_to_function_call_in_current_scope(zipper, :resources, 1),
           {:ok, zipper} <- Igniter.Code.Common.move_to_do_block(zipper) do

        # Append each resource declaration with define blocks as a child of the resources block
        zipper =
          zipper
          |> Sourceror.Zipper.append_child(
            quote do
              resource unquote(workspace_module) do
                define :create_workspace, action: :create, args: [:name]
                define :get_workspace_by_id, get_by: [:id], action: :read
              end
            end
          )
          |> Sourceror.Zipper.append_child(
            quote do
              resource unquote(workspace_user_module) do
                define :create_workspace_user, action: :create, args: [:role, :workspace_id, :user_id]

                define :get_workspace_users_by_workspace_id,
                  action: :get_workspace_users_by_workspace_id,
                  args: [:workspace_id]

                define :delete_workspace_user, action: :destroy
              end
            end
          )
          |> Sourceror.Zipper.append_child(
            quote do
              resource unquote(invitation_module) do
                define :create_invitation, action: :create, args: [:email, :role, :workspace_id]
                define :get_pending_invitations_by_email, action: :get_pending_by_email, args: [:email]
                define :list_all_pending_invitations, action: :get_all_pending_invitations
                define :resend_invitation, action: :resend_invitation
                define :accept_invitation, action: :accept_invitation
                define :revoke_invitation, action: :revoke_invitation
              end
            end
          )

        {:ok, zipper}
      else
        _ ->
          # If we can't find resources block, return unchanged
          {:ok, zipper}
      end
    end)
  end

  defp generate_migrations(igniter) do
    repo_module = igniter.assigns.repo_module

    # Generate workspace migration
    igniter
    |> generate_workspace_migration(repo_module)
    |> generate_workspace_user_migration(repo_module)
    |> generate_invitation_migration(repo_module)
  end

  defp generate_workspace_migration(igniter, _repo_module) do
    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d%H%M%S")
    migration_name = "create_workspaces"

    migration_content = """
    defmodule #{inspect(Module.concat([igniter.assigns.repo_module, Migrations, CreateWorkspaces]))} do
      use Ecto.Migration

      def change do
        create table(:workspaces, primary_key: false) do
          add :id, :binary_id, primary_key: true
          add :name, :string, null: false

          timestamps(type: :utc_datetime_usec)
        end

        create index(:workspaces, [:name])
      end
    end
    """

    Igniter.create_new_file(igniter, "priv/repo/migrations/#{timestamp}_#{migration_name}.exs", migration_content)
  end

  defp generate_workspace_user_migration(igniter, _repo_module) do
    timestamp =
      DateTime.utc_now()
      |> DateTime.add(1, :second)
      |> Calendar.strftime("%Y%m%d%H%M%S")
    migration_name = "create_workspaces_users"

    migration_content = """
    defmodule #{inspect(Module.concat([igniter.assigns.repo_module, Migrations, CreateWorkspacesUsers]))} do
      use Ecto.Migration

      def change do
        create table(:workspaces_users, primary_key: false) do
          add :id, :binary_id, primary_key: true
          add :role, :string, null: false, default: "member"

          add :workspace_id,
            references(:workspaces, type: :binary_id, on_delete: :delete_all),
            null: false

          add :user_id,
            references(:users, type: :binary_id, on_delete: :delete_all),
            null: false

          timestamps(type: :utc_datetime_usec)
        end

        create index(:workspaces_users, [:workspace_id])
        create index(:workspaces_users, [:user_id])
        create unique_index(:workspaces_users, [:workspace_id, :user_id])
      end
    end
    """

    Igniter.create_new_file(igniter, "priv/repo/migrations/#{timestamp}_#{migration_name}.exs", migration_content)
  end

  defp generate_invitation_migration(igniter, _repo_module) do
    timestamp =
      DateTime.utc_now()
      |> DateTime.add(2, :second)
      |> Calendar.strftime("%Y%m%d%H%M%S")
    migration_name = "create_invitations"

    migration_content = """
    defmodule #{inspect(Module.concat([igniter.assigns.repo_module, Migrations, CreateInvitations]))} do
      use Ecto.Migration

      def change do
        execute "CREATE EXTENSION IF NOT EXISTS citext", ""

        create table(:invitations, primary_key: false) do
          add :id, :binary_id, primary_key: true
          add :email, :citext, null: false
          add :role, :string, null: false
          add :token, :string, null: false
          add :status, :string, null: false, default: "created"

          add :workspace_id,
            references(:workspaces, type: :binary_id, on_delete: :delete_all),
            null: false

          add :user_id,
            references(:users, type: :binary_id, on_delete: :delete_all),
            null: false

          timestamps(type: :utc_datetime_usec)
        end

        create index(:invitations, [:email])
        create index(:invitations, [:workspace_id])
        create index(:invitations, [:status])
        create index(:invitations, [:updated_at])
      end
    end
    """

    Igniter.create_new_file(igniter, "priv/repo/migrations/#{timestamp}_#{migration_name}.exs", migration_content)
  end

  defp add_configuration(igniter) do
    domain_module = igniter.assigns.domain_module
    workspace_user_module = igniter.assigns.workspace_user_module
    invitation_module = igniter.assigns.invitation_module
    otp_app = Igniter.Project.Application.app_name(igniter)

    config_content = """

    # AshWorkspace Configuration
    config :ash_workspace,
      domain: #{inspect(domain_module)},
      workspace_user_resource: #{inspect(workspace_user_module)},
      invitation_resource: #{inspect(invitation_module)},
      mailer: #{inspect(Module.concat([Macro.camelize(to_string(otp_app)), Mailer]))},
      from_email: {"#{Macro.camelize(to_string(otp_app))} Team", "noreply@example.com"},
      app_name: "#{Macro.camelize(to_string(otp_app))}",
      url_builder: &#{inspect(Module.concat([Macro.camelize(to_string(otp_app)) <> "Web", Router, Helpers]))}.invitation_acceptance_url/3
    """

    # Add to config/config.exs
    Igniter.Project.Config.configure(igniter, "config.exs", otp_app, [:ash_workspace], config_content)
  end

  defp update_user_resource(igniter) do
    domain_module = igniter.assigns.domain_module
    user_module = Module.concat([domain_module, User])
    workspace_user_module = igniter.assigns.workspace_user_module
    workspace_module = igniter.assigns.workspace_module
    otp_app = Igniter.Project.Application.app_name(igniter)

    Mix.shell().info("🔧 Updating User resource: #{inspect(user_module)}")

    igniter
    # Add confirmation add-on using AshAuthentication helper
    |> AshAuthentication.Igniter.add_new_add_on(
      user_module,
      :confirmation,
      :confirm_new_user,
      """
      confirmation :confirm_new_user do
        monitor_fields [:email]
        confirm_on_create? true
        confirm_on_update? false
        require_interaction? true
        confirmed_at_field :confirmed_at
        auto_confirm_actions [:sign_in_with_magic_link, :reset_password_with_token]
        sender #{inspect(user_module)}.Senders.SendNewUserConfirmationEmail
      end
      """
    )
    # Add password attributes
    |> Ash.Resource.Igniter.add_new_attribute(user_module, :hashed_password, """
    attribute :hashed_password, :string do
      allow_nil? false
      sensitive? true
    end
    """)
    |> Ash.Resource.Igniter.add_new_attribute(user_module, :confirmed_at, """
    attribute :confirmed_at, :utc_datetime_usec
    """)
    # Ensure :owner role is in role attribute constraints
    |> add_owner_role_to_constraints(user_module)
    # Add code interfaces
    |> add_code_interface(user_module)
    # Add workspace relationships
    |> add_workspace_relationships(user_module, workspace_user_module, workspace_module)
    # Add password strategy
    |> AshAuthentication.Igniter.add_new_strategy(
      user_module,
      :password,
      :password,
      """
      password :password do
        identity_field :email

        resettable do
          sender #{inspect(user_module)}.Senders.SendPasswordResetEmail
          password_reset_action_name :reset_password_with_token
          request_password_reset_action_name :request_password_reset_token
        end
      end
      """
    )
    # Add password actions
    |> add_password_actions(user_module, domain_module)
    # Add policies for password authentication actions
    |> add_password_policies(user_module)
    |> tap(fn _ -> Mix.shell().info("  ✅ User resource updated successfully") end)
  end

  # Add :owner to the role attribute constraints if a role attribute exists
  defp add_owner_role_to_constraints(igniter, user_module) do
    Mix.shell().info("  → Ensuring :owner role is in role attribute constraints")

    try do
      Igniter.Project.Module.find_and_update_module!(igniter, user_module, fn zipper ->
        # Debug: Let's see what nodes we can find
        all_attributes =
          Sourceror.Zipper.traverse(zipper, [], fn z, acc ->
            node = Sourceror.Zipper.node(z)
            case node do
              {:attribute, _, [name | _]} ->
                {z, [{name, node} | acc]}
              _ ->
                {z, acc}
            end
          end)
          |> elem(1)

        # Mix.shell().info("    Debug: Found attributes: #{inspect(Enum.map(all_attributes, fn {name, _} -> name end))}")

        # Look for attribute :role in the attributes block
        case Igniter.Code.Common.move_to(zipper, fn z ->
          node = Sourceror.Zipper.node(z)
          case node do
            {:attribute, _, [{:__block__, _, [:role]} | _]} ->
              Mix.shell().info("    Debug: Found role attribute!")
              true
            {:attribute, _, [:role | _]} ->
              Mix.shell().info("    Debug: Found role attribute (simple form)!")
              true
            _ ->
              false
          end
        end) do
          {:ok, attr_zipper} ->
            Mix.shell().info("    Debug: Successfully moved to role attribute")
            # Found role attribute, navigate into its do block
            case Igniter.Code.Common.move_to_do_block(attr_zipper) do
              {:ok, do_block_zipper} ->
                Mix.shell().info("    Debug: Found do block")
                # Look for constraints call
                case Igniter.Code.Common.move_to(do_block_zipper, fn z ->
                  node = Sourceror.Zipper.node(z)
                  match?({:constraints, _, _}, node)
                end) do
                  {:ok, constraints_zipper} ->
                    Mix.shell().info("    Debug: Found constraints")
                    # Found constraints, try to update the one_of list
                    node = Sourceror.Zipper.node(constraints_zipper)
                    # Mix.shell().info("    Debug: Constraints node: #{inspect(node)}")
                    case node do
                      # Handle the wrapped format with __block__
                      {:constraints, meta, [[{{:__block__, _, [:one_of]}, {:__block__, list_meta, [list]}}]]} when is_list(list) ->
                        # Extract the actual atom values from the list
                        current_roles = Enum.map(list, fn
                          {:__block__, _, [role]} -> role
                          role -> role
                        end)

                        if :owner in current_roles do
                          Mix.shell().info("    ✓ :owner already in role constraints")
                          {:ok, zipper}
                        else
                          Mix.shell().info("    ✓ Adding :owner to role constraints")
                          # Add :owner wrapped in __block__ to match the format
                          new_item = {:__block__, [trailing_comments: [], leading_comments: [], line: 137, column: 50], [:owner]}
                          new_list = list ++ [new_item]
                          new_node = {:constraints, meta, [[{{:__block__, [trailing_comments: [], leading_comments: [], format: :keyword, line: 137, column: 19], [:one_of]}, {:__block__, list_meta, [new_list]}}]]}
                          updated_zipper = Sourceror.Zipper.replace(constraints_zipper, new_node)
                          {:ok, Sourceror.Zipper.top(updated_zipper)}
                        end
                      # Simple format without __block__ wrappers
                      {:constraints, meta, [[{:one_of, list}]]} when is_list(list) ->
                        if :owner in list do
                          Mix.shell().info("    ✓ :owner already in role constraints")
                          {:ok, zipper}
                        else
                          Mix.shell().info("    ✓ Adding :owner to role constraints")
                          new_list = list ++ [:owner]
                          new_node = {:constraints, meta, [[{:one_of, new_list}]]}
                          updated_zipper = Sourceror.Zipper.replace(constraints_zipper, new_node)
                          {:ok, Sourceror.Zipper.top(updated_zipper)}
                        end
                      _ ->
                        Mix.shell().info("    ℹ Unexpected constraints format")
                        {:warning, zipper}
                    end
                  _ ->
                    Mix.shell().info("    ℹ No constraints found on role attribute")
                    {:warning, zipper}
                end
              _ ->
                Mix.shell().info("    ℹ Role attribute has no do block")
                {:warning, zipper}
            end
          _ ->
            Mix.shell().info("    ℹ No role attribute found")
            {:warning, zipper}
        end
      end)
      |> then(fn updated_igniter ->
        # Check if we should show a warning
        case updated_igniter do
          %{assigns: %{show_role_warning: true}} ->
            add_role_constraint_warning(updated_igniter)
          _ ->
            updated_igniter
        end
      end)
    rescue
      e ->
        Mix.shell().info("    ⚠ Error updating role constraints: #{inspect(e)}")
        add_role_constraint_warning(igniter)
    end
  end

  defp add_role_constraint_warning(igniter) do
    Igniter.add_warning(igniter, """
    ⚠️  IMPORTANT: Please update your User resource role attribute!

    The MakeOwnerRole change requires :owner to be added to the role attribute constraints.

    Please update your User resource (lib/*/accounts/user.ex):

    BEFORE:
      attribute :role, :atom do
        constraints one_of: [:admin, :user, :chat_only]
        default :user
        allow_nil? false
      end

    AFTER:
      attribute :role, :atom do
        constraints one_of: [:admin, :user, :chat_only, :owner]
        default :user
        allow_nil? false
      end

    Without this change, user registration will fail silently.
    """)
  end

  # Add code_interface block with helpers for User lookups
  defp add_code_interface(igniter, user_module) do
    Mix.shell().info("  → Adding code interfaces (get_by_id, get_by_email)")

    Igniter.Project.Module.find_and_update_module!(igniter, user_module, fn zipper ->
      with {:ok, zipper} <-
             Igniter.Code.Function.move_to_function_call_in_current_scope(zipper, :code_interface, 1),
           {:ok, zipper} <- Igniter.Code.Common.move_to_do_block(zipper) do
        # code_interface block exists, add inside it
        {:ok, Igniter.Code.Common.add_code(zipper, """
        define :get_by_id, get_by: [:id], action: :read
        define :get_by_email, get_by_identity: :unique_email, action: :read
        """)}
      else
        _ ->
          # code_interface block doesn't exist, create it
          {:ok, Igniter.Code.Common.add_code(zipper, """
          code_interface do
            define :get_by_id, get_by: [:id], action: :read
            define :get_by_email, get_by_identity: :unique_email, action: :read
          end
          """)}
      end
    end)
  end

  # Add workspace relationships to User resource
  defp add_workspace_relationships(igniter, user_module, workspace_user_module, workspace_module) do
    Mix.shell().info("  → Adding workspace relationships")

    Igniter.Project.Module.find_and_update_module!(igniter, user_module, fn zipper ->
      with {:ok, zipper} <-
             Igniter.Code.Function.move_to_function_call_in_current_scope(zipper, :relationships, 1),
           {:ok, zipper} <- Igniter.Code.Common.move_to_do_block(zipper) do
        # relationships block exists, add inside it
        {:ok, Igniter.Code.Common.add_code(zipper, """
        has_many :workspace_users, #{inspect(workspace_user_module)}

        many_to_many :workspaces, #{inspect(workspace_module)} do
          through #{inspect(workspace_user_module)}
        end
        """)}
      else
        _ ->
          # relationships block doesn't exist, create it
          {:ok, Igniter.Code.Common.add_code(zipper, """
          relationships do
            has_many :workspace_users, #{inspect(workspace_user_module)}

            many_to_many :workspaces, #{inspect(workspace_module)} do
              through #{inspect(workspace_user_module)}
            end
          end
          """)}
      end
    end)
  end

  # Add all password-related actions
  defp add_password_actions(igniter, user_module, domain_module) do
    Mix.shell().info("  → Adding password authentication actions")

    igniter
    |> Ash.Resource.Igniter.add_new_action(user_module, :sign_in_with_password, """
    read :sign_in_with_password do
      description "Attempt to sign in using an email and password."
      get? true

      argument :email, :ci_string do
        description "The email to use for retrieving the user."
        allow_nil? false
      end

      argument :password, :string do
        description "The password to check for the matching user."
        allow_nil? false
        sensitive? true
      end

      prepare AshAuthentication.Strategy.Password.SignInPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end
    """)
    |> Ash.Resource.Igniter.add_new_action(user_module, :sign_in_with_token, """
    read :sign_in_with_token do
      description "Attempt to sign in using a short-lived sign in token."
      get? true

      argument :token, :string do
        description "The short-lived sign in token."
        allow_nil? false
        sensitive? true
      end

      prepare AshAuthentication.Strategy.Password.SignInWithTokenPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end
    """)
    |> Ash.Resource.Igniter.add_new_action(user_module, :register_with_password, """
    create :register_with_password do
      description "Register a new user with an email and password."

      argument :email, :ci_string do
        allow_nil? false
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      argument :workspace_name, :string do
        allow_nil? true
      end

      change set_attribute(:email, arg(:email))
      change AshAuthentication.Strategy.Password.HashPasswordChange
      change AshAuthentication.GenerateTokenChange
      change #{inspect(domain_module)}.Changes.CreateDefaultWorkspace
      change #{inspect(domain_module)}.Changes.MakeOwnerRole

      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end
    """)
    |> Ash.Resource.Igniter.add_new_action(user_module, :request_password_reset_token, """
    action :request_password_reset_token do
      description "Send password reset instructions to a user if they exist."

      argument :email, :ci_string do
        allow_nil? false
      end

      run {AshAuthentication.Strategy.Password.RequestPasswordReset, action: :get_by_email}
    end
    """)
    |> Ash.Resource.Igniter.add_new_action(user_module, :reset_password_with_token, """
    update :reset_password_with_token do
      argument :reset_token, :string do
        allow_nil? false
        sensitive? true
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      validate AshAuthentication.Strategy.Password.ResetTokenValidation
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation
      change AshAuthentication.Strategy.Password.HashPasswordChange
      change AshAuthentication.GenerateTokenChange
    end
    """)
  end

  # Add policies for password authentication actions
  defp add_password_policies(igniter, user_module) do
    Mix.shell().info("  → Adding policies for password authentication")

    Igniter.Project.Module.find_and_update_module!(igniter, user_module, fn zipper ->
      with {:ok, zipper} <-
             Igniter.Code.Function.move_to_function_call_in_current_scope(zipper, :policies, 1),
           {:ok, zipper} <- Igniter.Code.Common.move_to_do_block(zipper) do
        # policies block exists, add inside it
        {:ok, Igniter.Code.Common.add_code(zipper, """
        # Password authentication policies
        policy action(:register_with_password) do
          authorize_if always()
        end

        policy action(:sign_in_with_password) do
          authorize_if always()
        end

        policy action(:sign_in_with_token) do
          authorize_if always()
        end

        policy action(:request_password_reset_token) do
          authorize_if always()
        end

        policy action(:reset_password_with_token) do
          authorize_if always()
        end
        """)}
      else
        _ ->
          # policies block doesn't exist, create it with auth bypass and password policies
          {:ok, Igniter.Code.Common.add_code(zipper, """
          policies do
            # Required for auth flows
            bypass AshAuthentication.Checks.AshAuthenticationInteraction do
              authorize_if always()
            end

            # Password authentication policies
            policy action(:register_with_password) do
              authorize_if always()
            end

            policy action(:sign_in_with_password) do
              authorize_if always()
            end

            policy action(:sign_in_with_token) do
              authorize_if always()
            end

            policy action(:request_password_reset_token) do
              authorize_if always()
            end

            policy action(:reset_password_with_token) do
              authorize_if always()
            end
          end
          """)}
      end
    end)
  end

  defp generate_ui_components(igniter) do
    otp_app = Igniter.Project.Application.app_name(igniter)
    module_prefix = Macro.camelize(to_string(otp_app))
    template_dir = Path.join([__DIR__, "..", "..", "..", "priv", "templates"])

    # Generate AshWorkspace-specific components needed by team LiveView
    # These are placed in a separate namespace to avoid conflicts with existing components
    igniter
    |> generate_from_template(
      "#{template_dir}/components/ash_workspace/core_components.ex",
      "lib/#{otp_app}_web/components/ash_workspace/core_components.ex",
      module_prefix,
      otp_app
    )
  end

  defp generate_liveview_files(igniter) do
    otp_app = Igniter.Project.Application.app_name(igniter)
    module_prefix = Macro.camelize(to_string(otp_app))

    # Get template directory relative to this file
    template_dir = Path.join([__DIR__, "..", "..", "..", "priv", "templates"])

    # Generate auth LiveViews
    igniter
    |> generate_from_template("#{template_dir}/live/auth_live/register.ex", "lib/#{otp_app}_web/live/auth_live/register.ex", module_prefix, otp_app)
    |> generate_from_template("#{template_dir}/live/auth_live/sign_in.ex", "lib/#{otp_app}_web/live/auth_live/sign_in.ex", module_prefix, otp_app)
    |> generate_from_template("#{template_dir}/live/auth_live/reset.ex", "lib/#{otp_app}_web/live/auth_live/reset.ex", module_prefix, otp_app)
    |> generate_from_template("#{template_dir}/live/auth_live/components.ex", "lib/#{otp_app}_web/live/auth_live/components.ex", module_prefix, otp_app)
    # Generate invitation acceptance LiveViews
    |> generate_from_template("#{template_dir}/live/invitation_acceptance_live/register_index.ex", "lib/#{otp_app}_web/live/invitation_acceptance_live/register_index.ex", module_prefix, otp_app)
    |> generate_from_template("#{template_dir}/live/invitation_acceptance_live/sign_in_index.ex", "lib/#{otp_app}_web/live/invitation_acceptance_live/sign_in_index.ex", module_prefix, otp_app)
    |> generate_from_template("#{template_dir}/live/invitation_acceptance_live/component.ex", "lib/#{otp_app}_web/live/invitation_acceptance_live/component.ex", module_prefix, otp_app)
    # Generate team management LiveViews (for admins)
    |> generate_from_template("#{template_dir}/live/team_live/index.ex", "lib/#{otp_app}_web/live/team_live/index.ex", module_prefix, otp_app)
    |> generate_from_template("#{template_dir}/live/team_live/components.ex", "lib/#{otp_app}_web/live/team_live/components.ex", module_prefix, otp_app)
  end

  defp generate_from_template(igniter, template_path, target_path, module_prefix, otp_app) do
    # Mix.shell().info("generate #{target_path} from #{template_path}")
    # Skip standard ash_authentication_phoenix files if they already exist
    # (users may have customized them or installed ash_authentication_phoenix separately)
    skip_if_exists? = String.contains?(target_path, [
      "/controllers/auth_controller.ex",
      "/ash_workspace_live_user_auth.ex",
      "/ash_workspace_auth_overrides.ex"
    ])

    if skip_if_exists? && File.exists?(target_path) do
      # File exists and is a standard auth file - skip it
      igniter
    else
      case File.read(template_path) do
        {:ok, content} ->
          # Replace placeholders
          processed_content =
            content
            |> String.replace("__MODULE_PREFIX__", module_prefix)
            |> String.replace("__OTP_APP__", to_string(otp_app))
            |> String.replace("__APP_NAME__", module_prefix)

          Igniter.create_new_file(igniter, target_path, processed_content)

        {:error, reason} ->
          # Log error but continue
          Mix.shell().info("Skipping #{target_path}: #{inspect(reason)}")
          igniter
      end
    end
  end

  defp generate_controller_files(igniter) do
    otp_app = Igniter.Project.Application.app_name(igniter)
    module_prefix = Macro.camelize(to_string(otp_app))
    template_dir = Path.join([__DIR__, "..", "..", "..", "priv", "templates"])

    igniter
    |> generate_from_template("#{template_dir}/controllers/auth_controller.ex", "lib/#{otp_app}_web/controllers/auth_controller.ex", module_prefix, otp_app)
    |> generate_from_template("#{template_dir}/controllers/invitation_controller.ex", "lib/#{otp_app}_web/controllers/invitation_controller.ex", module_prefix, otp_app)
  end

  defp generate_helper_modules(igniter) do
    otp_app = Igniter.Project.Application.app_name(igniter)
    module_prefix = Macro.camelize(to_string(otp_app))
    template_dir = Path.join([__DIR__, "..", "..", "..", "priv", "templates"])

    igniter
    |> generate_from_template("#{template_dir}/ash_workspace_live_user_auth.ex", "lib/#{otp_app}_web/ash_workspace_live_user_auth.ex", module_prefix, otp_app)
    |> generate_from_template("#{template_dir}/ash_workspace_auth_overrides.ex", "lib/#{otp_app}_web/ash_workspace_auth_overrides.ex", module_prefix, otp_app)
    # Generate email sender modules
    |> generate_from_template("#{template_dir}/senders/send_new_user_confirmation_email.ex", "lib/#{otp_app}/accounts/user/senders/send_new_user_confirmation_email.ex", module_prefix, otp_app)
    |> generate_from_template("#{template_dir}/senders/send_password_reset_email.ex", "lib/#{otp_app}/accounts/user/senders/send_password_reset_email.ex", module_prefix, otp_app)
    |> generate_from_template("#{template_dir}/senders/send_invitation_email.ex", "lib/#{otp_app}/accounts/invitation/senders/send_invitation_email.ex", module_prefix, otp_app)
    # Generate workspace creation change module
    |> generate_from_template("#{template_dir}/changes/create_default_workspace.ex", "lib/#{otp_app}/accounts/changes/create_default_workspace.ex", module_prefix, otp_app)
    # Generate owner role change module
    |> generate_from_template("#{template_dir}/changes/make_owner_role.ex", "lib/#{otp_app}/accounts/changes/make_owner_role.ex", module_prefix, otp_app)
    # validators
    |> generate_from_template("#{template_dir}/validators/email_uniqueness_in_workspace.ex", "lib/#{otp_app}/accounts/validators/email_uniqueness_in_workspace.ex", module_prefix, otp_app)
    |> generate_from_template("#{template_dir}/validators/strong_password_validation.ex", "lib/#{otp_app}/accounts/validators/strong_password_validation.ex", module_prefix, otp_app)
  end

  defp update_router(igniter) do
    # Get the web module using Igniter's helper (e.g., RoboadvisorWeb, not Roboadvisor.Web)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)

    # Get the router using Igniter's helper
    {igniter, router} = Igniter.Libs.Phoenix.select_router(igniter)

    igniter
    # Add guest authentication routes (register, sign-in, reset)
    |> Igniter.Libs.Phoenix.add_scope(
      "/",
      """
      pipe_through :browser

      # AshWorkspace authentication routes - custom registration creates workspace
      ash_authentication_live_session :guest,
        on_mount: [{#{inspect(web_module)}.AshWorkspaceLiveUserAuth, :live_no_user}] do
        live "/register", AuthLive.Register
        live "/sign-in", AuthLive.SignIn
        live "/reset", AuthLive.Reset
      end
      """,
      arg2: web_module,
      router: router
    )
    # Add team management route (requires admin or owner role)
    |> Igniter.Libs.Phoenix.add_scope(
      "/",
      """
      pipe_through :browser
      # Team management - requires admin or owner role
      ash_authentication_live_session :team_admin,
        on_mount: [
          {#{inspect(web_module)}.AshWorkspaceLiveUserAuth, :live_user_required},
          {#{inspect(web_module)}.AshWorkspaceLiveUserAuth, :admin_or_owner}
        ] do
        live "/team", TeamLive.Index
      end
      """,
      arg2: web_module,
      router: router
    )
    # Add invitation acceptance routes
    |> Igniter.Libs.Phoenix.add_scope(
      "/invitation",
      """
      pipe_through :browser

      get "/accept/:email/:token", InvitationController, :accept
      live "/accept/register/:email/:token", InvitationAcceptanceAuthLive.RegisterIndex, :index
      live "/accept/sign-in/:email/:token", InvitationAcceptanceAuthLive.SignInIndex, :index
      """,
      arg2: web_module,
      router: router
    )
    # Add auth callback routes
    |> Igniter.Libs.Phoenix.add_scope(
      "/auth",
      """
      pipe_through :browser

      get "/success", AuthController, :success
      get "/failure", AuthController, :failure
      """,
      arg2: web_module,
      router: router
    )
    # Add warning about potential route conflicts
    |> add_route_conflict_warning()
  end

  defp add_route_conflict_warning(igniter) do
    Igniter.add_warning(igniter, """

    ⚠️  IMPORTANT: Please check your router for duplicate routes!

    AshWorkspace has added the following routes:
    - GET  /register (custom workspace registration)
    - GET  /sign-in  (authentication)
    - GET  /reset    (password reset)
    - GET  /team     (admin-only team management)

    If you have existing routes for /register, /sign-in, or /reset, you may see
    route conflicts. Please review your router and:

    1. Remove or comment out the `register_path:` option from `sign_in_route`
    2. Remove or comment out any duplicate LiveView routes for the above paths
    3. Ensure only ONE route exists for each path

    Example of what to remove:
      # BEFORE:
      sign_in_route register_path: "/register", reset_path: "/reset", ...

      # AFTER (remove register_path since we provide custom registration):
      sign_in_route reset_path: "/reset", ...

    Run `mix phx.routes` to verify your routes are correct.
    """)
  end

  defp print_success_message(igniter) do
    Igniter.add_notice(igniter, """

    ✅ AshWorkspace installation complete!

    Generated files:
    - ✅ Workspace, WorkspaceUser, and Invitation resources
    - ✅ Database migrations
    - ✅ LiveView files for authentication (register, sign-in)
    - ✅ LiveView files for invitation acceptance
    - ✅ Auth and Invitation controllers
    - ✅ Helper modules (AshWorkspaceLiveUserAuth, AshFrameworkAuthOverrides)
    - ✅ Router routes for auth and invitations
    - ✅ Configuration file

    ⚠️  Manual steps required:

    1. Add resources to your domain module (lib/YOUR_APP/accounts.ex):

       resources do
         # ... existing resources ...
         resource YourApp.Accounts.Workspace
         resource YourApp.Accounts.WorkspaceUser
         resource YourApp.Accounts.Invitation

         # Add code interface functions
         define :create_workspace, resource: YourApp.Accounts.Workspace, action: :create, args: [:name]
         define :get_workspace_by_id, resource: YourApp.Accounts.Workspace, action: :get_workspace_by_id, args: [:id]
         define :create_workspace_user, resource: YourApp.Accounts.WorkspaceUser, action: :create, args: [:role, :workspace_id, :user_id]
         define :create_invitation, resource: YourApp.Accounts.Invitation, action: :create, args: [:email, :role, :workspace_id]
         define :get_pending_invitations_by_email, resource: YourApp.Accounts.Invitation, action: :get_pending_by_email, args: [:email]
         define :accept_invitation, resource: YourApp.Accounts.Invitation, action: :accept, args: [:id]
       end

    2. Update your User resource to add:
       - Password authentication strategy (if not already present)
       - Workspace relationships:

         relationships do
           has_many :workspace_users, YourApp.Accounts.WorkspaceUser
           many_to_many :workspaces, YourApp.Accounts.Workspace do
             through YourApp.Accounts.WorkspaceUser
           end
         end

    3. Run migrations: mix ecto.migrate

    4. Test the registration flow:
       - Start server: mix phx.server
       - Visit: http://localhost:4000/register

    📚 For more information, see: https://hexdocs.pm/ash_workspace
    """)
  end

  defp run_ash_codegen(igniter) do
    # After all resources are created, run ash.codegen to generate migrations and snapshots
    igniter = Igniter.add_task(igniter, "ash_postgres.generate_migrations", ["--name", "install_ash_workspace"])

    # If --migrate flag is set, also run migrations
    if igniter.args.options[:migrate] do
      Igniter.add_task(igniter, "ecto.migrate")
    else
      igniter
    end
  end

  end
else
  defmodule Mix.Tasks.AshWorkspace.Install do
    @moduledoc "Installs AshWorkspace. Should be run with `mix igniter.install ash_workspace`"
    @shortdoc @moduledoc
    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_workspace.install' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
