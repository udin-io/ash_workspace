# Manual Installation Guide

This guide shows how to use `ash_workspace` **without** the Igniter installer (which hasn't been built yet). This is useful for:
- Understanding how the extension works
- Testing during development
- Custom installations where you want full control

## Overview

Manual installation involves:
1. Adding the dependency
2. Creating the three resources (Workspace, WorkspaceUser, Invitation)
3. Updating your User resource
4. Creating migrations
5. Configuring the extension

## Step 1: Add Dependency

### Option A: From Hex (when published)

```elixir
# mix.exs
def deps do
  [
    {:ash_workspace, "~> 0.1.0"}
  ]
end
```

### Option B: From Local Path (for development)

```elixir
# mix.exs
def deps do
  [
    {:ash_workspace, path: "../ash_workspace"}
  ]
end
```

Then run:
```bash
mix deps.get
```

## Step 2: Create Workspace Resource

Create `lib/my_app/accounts/workspace.ex`:

```elixir
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
```

## Step 3: Create WorkspaceUser Resource

Create `lib/my_app/accounts/workspace_user.ex`:

```elixir
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
```

## Step 4: Create Invitation Resource

Create `lib/my_app/accounts/invitation.ex`:

```elixir
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
```

## Step 5: Update User Resource

Add these to your existing `lib/my_app/accounts/user.ex`:

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    # ... your existing configuration

  # Add to your existing register action:
  create :register_with_password do
    # ... your existing arguments

    # ADD THIS:
    argument :workspace_name, :string do
      allow_nil? true
    end

    # ... your existing changes

    # ADD THIS:
    change AshWorkspace.Changes.CreateDefaultWorkspace

    # ... rest of your action
  end

  # Add to your relationships section:
  relationships do
    # ... your existing relationships

    # ADD THESE:
    has_many :workspace_users, MyApp.Accounts.WorkspaceUser
    has_many :invitations, MyApp.Accounts.Invitation

    many_to_many :workspaces, MyApp.Accounts.Workspace do
      through MyApp.Accounts.WorkspaceUser
    end
  end
end
```

## Step 6: Update Domain Module

Add the new resources to your domain:

```elixir
defmodule MyApp.Accounts do
  use Ash.Domain

  resources do
    resource MyApp.Accounts.User

    # ADD THESE:
    resource MyApp.Accounts.Workspace
    resource MyApp.Accounts.WorkspaceUser
    resource MyApp.Accounts.Invitation
  end
end
```

## Step 7: Create Migrations

### Migration 1: Create Workspaces

```bash
mix ecto.gen.migration create_workspaces
```

```elixir
defmodule MyApp.Repo.Migrations.CreateWorkspaces do
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
```

### Migration 2: Create WorkspaceUsers

```bash
mix ecto.gen.migration create_workspaces_users
```

```elixir
defmodule MyApp.Repo.Migrations.CreateWorkspacesUsers do
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
```

### Migration 3: Create Invitations

```bash
mix ecto.gen.migration create_invitations
```

```elixir
defmodule MyApp.Repo.Migrations.CreateInvitations do
  use Ecto.Migration

  def change do
    # Enable citext extension if not already enabled
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
```

### Run Migrations

```bash
mix ecto.migrate
```

## Step 8: Configuration

Add to `config/config.exs`:

```elixir
config :ash_workspace,
  domain: MyApp.Accounts,
  workspace_user_resource: MyApp.Accounts.WorkspaceUser,
  invitation_resource: MyApp.Accounts.Invitation,
  mailer: MyApp.Mailer,
  from_email: {"MyApp Team", "noreply@myapp.com"},
  app_name: "MyApp",
  url_builder: &MyAppWeb.Router.Helpers.invitation_acceptance_url/3

# Optional: Customize password requirements
config :ash_workspace, :password_requirements,
  min_length: 8,
  require_uppercase: true,
  require_lowercase: true,
  require_digit: true,
  require_special: true

# Optional: Customize email templates
config :ash_workspace, AshWorkspace.Senders.InvitationEmail,
  subject: fn workspace_name -> "Join #{workspace_name}!" end
```

## Step 9: Add Routes (Optional)

If you want invitation acceptance routes:

```elixir
# lib/my_app_web/router.ex
scope "/", MyAppWeb do
  pipe_through :browser

  # Invitation acceptance route
  get "/invitation/accept/:email/:token", InvitationAcceptanceController, :show
end
```

## Step 10: Verify Installation

Test that everything works:

```elixir
# Start your app
iex -S mix phx.server

# Create a workspace
{:ok, workspace} = MyApp.Accounts.create_workspace(%{name: "Test Workspace"})

# Register a user with workspace
{:ok, user} = MyApp.Accounts.register_with_password(%{
  email: "admin@example.com",
  password: "SecureP@ss123",
  password_confirmation: "SecureP@ss123",
  workspace_name: "My Workspace"
})

# Create an invitation
{:ok, invitation} = MyApp.Accounts.create_invitation(%{
  email: "newuser@example.com",
  role: :member,
  workspace_id: workspace.id,
  user_id: user.id
})
```

## Troubleshooting

### "undefined function get_workspace_users_by_workspace_id"

Make sure you added the code_interface to both:
- WorkspaceUser resource
- Your domain module has the WorkspaceUser resource listed

### "cannot find domain configuration"

Add the configuration block to `config/config.exs` as shown in Step 8.

### Emails not sending

Make sure:
1. Swoosh is configured in your app
2. You've set up a mailer module
3. The `url_builder` function in config returns a valid URL

### citext extension error

If the citext migration fails, run manually:
```sql
CREATE EXTENSION IF NOT EXISTS citext;
```

## Next Steps

After manual installation:
1. Test creating workspaces
2. Test user invitations
3. Verify emails are sent
4. Test invitation acceptance
5. Add authorization policies as needed

## Differences from Auto-Installation

When the Igniter installer is complete, it will:
- Automatically detect your domain and repo modules
- Generate these resources for you
- Create migrations automatically
- Add configuration automatically
- Offer to generate LiveView components

For now, manual installation gives you full control and helps you understand how the extension works.
