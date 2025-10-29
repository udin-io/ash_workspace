defmodule __MODULE_PREFIX__.Accounts.Invitation do
  use Ash.Resource,
    otp_app: :__OTP_APP__,
    domain: __MODULE_PREFIX__.Accounts,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  @days_to_expire 7

  postgres do
    table "invitations"
    repo __MODULE_PREFIX__.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:email, :role, :workspace_id, :user_id]

      change AshWorkspace.Changes.SetToken
      validate __MODULE_PREFIX__.Accounts.Validators.EmailUniquenessInWorkspace

      change after_action(&__MODULE_PREFIX__.Accounts.Invitation.Senders.SendInvitationEmail.after_action/3)
    end

    update :resend_invitation do
      require_atomic? false

      change AshWorkspace.Changes.SetToken

      change after_action(&__MODULE_PREFIX__.Accounts.Invitation.Senders.SendInvitationEmail.after_action/3)
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
    validate match(:email, ~r/^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$/),
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
    belongs_to :workspace, __MODULE_PREFIX__.Accounts.Workspace do
      allow_nil? false
    end

    belongs_to :user, __MODULE_PREFIX__.Accounts.User do
      allow_nil? false
    end
  end

  code_interface do
    define :get_pending_invitations_by_email,
      action: :get_pending_by_email,
      args: [:email]
  end
end
