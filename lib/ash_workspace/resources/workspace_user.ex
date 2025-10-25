defmodule AshWorkspace.Resources.WorkspaceUser do
  @moduledoc """
  Template and documentation for the WorkspaceUser join table resource.

  This module is NOT meant to be used directly. Instead, use the Igniter installer
  to generate a WorkspaceUser resource in your application:

      mix ash_workspace.install

  ## What is a WorkspaceUser?

  WorkspaceUser is a join table that connects users to workspaces with role-based access control.
  It enables:
  - Users to belong to multiple workspaces
  - Each workspace membership to have a specific role (admin, member, billing, etc.)
  - Fine-grained access control based on workspace membership

  ## Minimum Resource Definition

  The installer will generate:

      defmodule MyApp.Accounts.WorkspaceUser do
        use Ash.Resource,
          otp_app: :my_app,
          domain: MyApp.Accounts,
          data_layer: AshPostgres.DataLayer

        postgres do
          table "workspaces_users"
          repo MyApp.Repo
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

          attribute :workspace_id, :uuid do
            allow_nil? false
            public? true
          end

          attribute :user_id, :uuid do
            allow_nil? false
            public? true
          end

          timestamps()
        end

        relationships do
          belongs_to :workspace, MyApp.Accounts.Workspace
          belongs_to :user, MyApp.Accounts.User
        end

        code_interface do
          define :get_workspace_users_by_workspace_id,
            action: :get_workspace_users_by_workspace_id,
            args: [:workspace_id]
        end
      end

  ## Role System

  The default roles are:
  - `:admin` - Full workspace management permissions
  - `:member` - Standard user access
  - `:billing` - Billing and subscription management

  ### Customizing Roles

  You can extend or modify roles:

      attribute :role, :atom do
        allow_nil? false
        public? true
        default :member
        constraints one_of: [:owner, :admin, :member, :viewer, :billing]
      end

  ### Role-Based Policies

  Add policies to enforce role-based access:

      policies do
        policy action_type(:read) do
          authorize_if relates_to_actor_via(:user)
        end

        policy action_type([:update, :destroy]) do
          # Only admins can modify workspace memberships
          authorize_if expr(
            exists(workspace.workspace_users,
              user_id == ^actor(:id) and role == :admin
            )
          )
        end
      end

  ## Required for AshWorkspace

  The following are required for AshWorkspace features:

  1. **get_workspace_users_by_workspace_id read action** - Used by invitation validator
  2. **Code Interface** - Must expose the read action
  3. **Relationships** - Both workspace and user belongs_to relationships
  4. **Role Attribute** - With configurable roles

  ## Migration

      defmodule MyApp.Repo.Migrations.CreateWorkspacesUsers do
        use Ecto.Migration

        def change do
          create table(:workspaces_users, primary_key: false) do
            add :id, :binary_id, primary_key: true
            add :role, :string, null: false, default: "member"
            add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
              null: false
            add :user_id, references(:users, type: :binary_id, on_delete: :delete_all),
              null: false

            timestamps(type: :utc_datetime_usec)
          end

          create index(:workspaces_users, [:workspace_id])
          create index(:workspaces_users, [:user_id])
          create unique_index(:workspaces_users, [:workspace_id, :user_id])
        end
      end

  ## Additional Features

  ### Audit Trail

      attribute :invited_by_id, :uuid
      attribute :joined_at, :utc_datetime_usec

      belongs_to :invited_by, MyApp.Accounts.User

  ### Soft Deletes

      attribute :archived_at, :utc_datetime_usec

      actions do
        update :archive do
          change set_attribute(:archived_at, &DateTime.utc_now/0)
        end
      end
  """

  @doc false
  def __template__, do: :workspace_user
end
