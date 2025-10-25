defmodule AshWorkspace.Resources.Workspace do
  @moduledoc """
  Template and documentation for the Workspace resource.

  This module is NOT meant to be used directly. Instead, use the Igniter installer
  to generate a Workspace resource in your application:

      mix ash_workspace.install

  ## What is a Workspace?

  A workspace represents a multi-tenant container in your application. Each workspace can have:
  - Multiple users with different roles
  - Its own data and resources
  - Invitations to bring in new members

  ## Minimum Resource Definition

  The installer will generate a resource like this in your app:

      defmodule MyApp.Accounts.Workspace do
        use Ash.Resource,
          otp_app: :my_app,
          domain: MyApp.Accounts,
          data_layer: AshPostgres.DataLayer

        postgres do
          table "workspaces"
          repo MyApp.Repo
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
          has_many :workspace_users, MyApp.Accounts.WorkspaceUser
          has_many :invitations, MyApp.Accounts.Invitation

          many_to_many :users, MyApp.Accounts.User do
            through MyApp.Accounts.WorkspaceUser
          end
        end

        code_interface do
          define :get_workspace_by_id, get_by: [:id], action: :read
        end
      end

  ## Customization

  You can extend the generated resource with:

  ### Additional Attributes

      attribute :slug, :string do
        allow_nil? false
      end

      attribute :settings, :map, default: %{}

  ### Policies

      policies do
        policy action_type(:read) do
          authorize_if relates_to_actor_via(:users)
        end

        policy action_type([:create, :update, :destroy]) do
          authorize_if relates_to_actor_via([:workspace_users, :user],
            filter: expr(role == :admin)
          )
        end
      end

  ### Calculations

      calculations do
        calculate :member_count, :integer do
          calculation fn records, _context ->
            # Count workspace users
          end
        end
      end

  ### Code Interfaces

      code_interface do
        define :get_workspace_by_id, get_by: [:id], action: :read
        define :create_workspace, action: :create, args: [:name]
        define :list_workspaces, action: :read
      end

  ## Required for AshWorkspace Features

  For full AshWorkspace functionality, ensure you have:

  1. **Code Interface**: The `get_workspace_by_id` function
  2. **Relationships**: Properly defined relationships to User, WorkspaceUser, and Invitation
  3. **Table Name**: A consistent table name across environments

  ## Migration

  The installer will also generate a migration:

      defmodule MyApp.Repo.Migrations.CreateWorkspaces do
        use Ecto.Migration

        def change do
          create table(:workspaces, primary_key: false) do
            add :id, :binary_id, primary_key: true
            add :name, :string, null: false

            timestamps(type: :utc_datetime_usec)
          end
        end
      end
  """

  @doc false
  def __template__, do: :workspace
end
