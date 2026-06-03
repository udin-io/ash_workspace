defmodule __MODULE_PREFIX__.Accounts.WorkspaceUser do
  use Ash.Resource,
    otp_app: :__OTP_APP__,
    domain: __MODULE_PREFIX__.Accounts,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "workspaces_users"
    repo __MODULE_PREFIX__.Repo
  end

  policies do
    # Any workspace member can read membership records for their workspace
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:workspace, :workspace_users, :user])
    end

    # WorkspaceUser creation happens during registration (actor is nil, user is being created)
    # and during invitation acceptance. Safety relies on the domain not exposing a direct
    # create_workspace_user action publicly.
    policy action(:create) do
      authorize_if always()
    end

    # Only workspace admins can change member roles
    policy action(:update) do
      authorize_if expr(exists(workspace.workspace_users, user_id == ^actor(:id) and role == :admin))
    end

    # Only workspace admins can remove members
    policy action(:destroy) do
      authorize_if expr(exists(workspace.workspace_users, user_id == ^actor(:id) and role == :admin))
    end
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
      prepare build(load: [:user])
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

  identities do
    identity :unique_workspace_member, [:workspace_id, :user_id]
  end

  relationships do
    belongs_to :workspace, __MODULE_PREFIX__.Accounts.Workspace do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :user, __MODULE_PREFIX__.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end
  end

  code_interface do
    define :get_workspace_users_by_workspace_id,
      action: :get_workspace_users_by_workspace_id,
      args: [:workspace_id]
  end
end
