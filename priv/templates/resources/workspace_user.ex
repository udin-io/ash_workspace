defmodule __MODULE_PREFIX__.Accounts.WorkspaceUser do
  use Ash.Resource,
    otp_app: :__OTP_APP__,
    domain: __MODULE_PREFIX__.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "workspaces_users"
    repo __MODULE_PREFIX__.Repo
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
