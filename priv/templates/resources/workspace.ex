defmodule __MODULE_PREFIX__.Accounts.Workspace do
  use Ash.Resource,
    otp_app: :__OTP_APP__,
    domain: __MODULE_PREFIX__.Accounts,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "workspaces"
    repo __MODULE_PREFIX__.Repo
  end

  policies do
    # Any authenticated user can create a workspace (set as admin via CreateDefaultWorkspace)
    policy action(:create) do
      authorize_if actor_present()
    end

    # Only members of this workspace can read it
    policy action(:read) do
      authorize_if relates_to_actor_via([:workspace_users, :user])
    end

    # Only workspace admins can rename the workspace
    policy action(:update) do
      authorize_if expr(exists(workspace_users, user_id == ^actor(:id) and role == :admin))
    end

    # Only workspace admins can delete the workspace
    policy action(:destroy) do
      authorize_if expr(exists(workspace_users, user_id == ^actor(:id) and role == :admin))
    end
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
    has_many :workspace_users, __MODULE_PREFIX__.Accounts.WorkspaceUser
    has_many :invitations, __MODULE_PREFIX__.Accounts.Invitation

    many_to_many :users, __MODULE_PREFIX__.Accounts.User do
      through __MODULE_PREFIX__.Accounts.WorkspaceUser
    end
  end

  code_interface do
    define :get_workspace_by_id, get_by: [:id], action: :read
  end
end
