defmodule AshWorkspace.Resources.Invitation do
  @moduledoc """
  Template and documentation for the Invitation resource.

  This module is NOT meant to be used directly. Instead, use the Igniter installer
  to generate an Invitation resource in your application:

      mix ash_workspace.install

  ## What is an Invitation?

  An invitation allows workspace administrators to invite new users to join their workspace.
  Features include:
  - Secure token-based invitation links
  - Time-limited validity (default 7 days)
  - Role assignment
  - Email uniqueness validation within workspace
  - Automatic email delivery

  ## Minimum Resource Definition

  The installer will generate:

      defmodule MyApp.Accounts.Invitation do
        use Ash.Resource,
          otp_app: :my_app,
          domain: MyApp.Accounts,
          authorizers: [Ash.Policy.Authorizer],
          data_layer: AshPostgres.DataLayer

        @days_to_expire 7

        postgres do
          table "invitations"
          repo MyApp.Repo
        end

        actions do
          defaults [:read, :destroy]

          create :create do
            accept [:email, :role, :workspace_id, :user_id]

            change AshWorkspace.Changes.SetToken
            validate AshWorkspace.Validators.EmailUniquenessInWorkspace

            change after_action(
              &AshWorkspace.Hooks.SendInvitationEmail.after_action/3
            )
          end

          update :resend_invitation do
            require_atomic? false

            change AshWorkspace.Changes.SetToken

            change after_action(
              &AshWorkspace.Hooks.SendInvitationEmail.after_action/3
            )
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
          belongs_to :workspace, MyApp.Accounts.Workspace do
            allow_nil? false
          end

          belongs_to :user, MyApp.Accounts.User do
            allow_nil? false
          end
        end

        code_interface do
          define :get_pending_invitations_by_email,
            action: :get_pending_by_email,
            args: [:email]
        end
      end

  ## Key Features Explained

  ### Token Generation

  The `AshWorkspace.Changes.SetToken` change:
  - Generates a cryptographically secure 32-byte random token
  - Hashes it with Bcrypt for secure storage
  - Stores the raw token in changeset context for email delivery
  - Stores the hashed token in the database

  ### Email Validation

  The `AshWorkspace.Validators.EmailUniquenessInWorkspace` validator ensures:
  - No existing user in the workspace has this email
  - No pending invitation exists with this email

  ### Time-Based Expiration

  Invitations are considered expired after `@days_to_expire` days.
  The `ago/2` function in filters automatically checks:

      updated_at >= ago(@days_to_expire, "day")

  ### Status Lifecycle

  - `:created` - Invitation sent, awaiting acceptance
  - `:accepted` - User accepted and joined workspace
  - `:revoked` - Admin cancelled the invitation

  ## Customization

  ### Custom Expiration

      @days_to_expire 14  # 2 weeks instead of 7 days

  ### Additional Attributes

      attribute :message, :string  # Personal invitation message
      attribute :max_uses, :integer, default: 1  # Reusable invitations
      attribute :accepted_at, :utc_datetime_usec

  ### Custom Policies

      policies do
        # Only workspace admins can create invitations
        policy action(:create) do
          authorize_if expr(
            exists(workspace.workspace_users,
              user_id == ^actor(:id) and role == :admin
            )
          )
        end

        # Only inviter or workspace admin can revoke
        policy action(:revoke_invitation) do
          authorize_if expr(user_id == ^actor(:id))
          authorize_if expr(
            exists(workspace.workspace_users,
              user_id == ^actor(:id) and role == :admin
            )
          )
        end
      end

  ### Custom Email Sender

  Replace the default sender:

      change after_action(&MyApp.CustomInvitationSender.send_email/3)

  ## Required Configuration

      config :ash_workspace,
        domain: MyApp.Accounts,
        workspace_user_resource: MyApp.Accounts.WorkspaceUser,
        invitation_resource: MyApp.Accounts.Invitation,
        mailer: MyApp.Mailer,
        from_email: {"MyApp Team", "noreply@myapp.com"},
        url_builder: &MyAppWeb.Router.Helpers.invitation_url/3

  ## Migration

      defmodule MyApp.Repo.Migrations.CreateInvitations do
        use Ecto.Migration

        def change do
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

          # Enable citext extension for case-insensitive email matching
          execute "CREATE EXTENSION IF NOT EXISTS citext", ""
        end
      end
  """

  @doc false
  def __template__, do: :invitation
end
