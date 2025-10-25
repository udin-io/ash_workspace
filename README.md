# AshWorkspace

Multi-tenancy workspace and invitation system for Ash Framework applications.

[![Hex.pm](https://img.shields.io/hexpm/v/ash_workspace.svg)](https://hex.pm/packages/ash_workspace)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/ash_workspace)

## Features

- **🏢 Workspace Management**: Organize users into isolated workspaces with multi-tenancy support
- **✉️ Email Invitations**: Secure, token-based user invitations with automatic email delivery
- **🔐 Role-Based Access**: Flexible role system (admin, member, billing, custom roles)
- **🛡️ Security First**: Bcrypt-hashed tokens, time-limited invitations, email validation
- **🎨 Fully Customizable**: Override resources, validators, email templates, and more
- **⚡ Ash-Native**: Built specifically for Ash Framework with best practices

## Installation

Add `ash_workspace` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:ash_workspace, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
mix ash_workspace.install
```

The installer will:
- Generate Workspace, WorkspaceUser, and Invitation resources
- Create database migrations
- Update your User resource with workspace relationships
- Add configuration templates

## Quick Start

### 1. Configure your application

```elixir
# config/config.exs
config :ash_workspace,
  domain: MyApp.Accounts,
  workspace_user_resource: MyApp.Accounts.WorkspaceUser,
  invitation_resource: MyApp.Accounts.Invitation,
  mailer: MyApp.Mailer,
  from_email: {"MyApp Team", "noreply@myapp.com"},
  app_name: "MyApp",
  url_builder: &MyAppWeb.Router.Helpers.invitation_acceptance_url/3
```

### 2. Run migrations

```bash
mix ecto.migrate
```

### 3. Start using workspaces

```elixir
# Create a workspace
{:ok, workspace} = MyApp.Accounts.create_workspace(%{name: "Acme Corp"})

# Invite a user
{:ok, invitation} = MyApp.Accounts.create_invitation(%{
  email: "user@example.com",
  role: :member,
  workspace_id: workspace.id,
  user_id: current_user.id
})

# Accept invitation
{:ok, updated_invitation} = MyApp.Accounts.accept_invitation(invitation)
```

## How It Works

### Architecture

```
┌─────────────┐
│   User      │
└──────┬──────┘
       │
       │ many_to_many (through WorkspaceUser)
       │
       ▼
┌─────────────────┐      ┌──────────────────┐
│ WorkspaceUser   │──────│   Workspace      │
│ (Join Table)    │      │                  │
├─────────────────┤      ├──────────────────┤
│ - user_id       │      │ - name           │
│ - workspace_id  │      │                  │
│ - role          │      │                  │
└─────────────────┘      └──────────────────┘
                                  │
                                  │ has_many
                                  ▼
                         ┌──────────────────┐
                         │   Invitation     │
                         ├──────────────────┤
                         │ - email          │
                         │ - token (hashed) │
                         │ - role           │
                         │ - status         │
                         │ - workspace_id   │
                         └──────────────────┘
```

### Invitation Flow

1. **Admin creates invitation** → `create_invitation/1`
2. **System generates token** → `AshWorkspace.Changes.SetToken`
3. **System validates email** → `AshWorkspace.Validators.EmailUniquenessInWorkspace`
4. **System sends email** → `AshWorkspace.Hooks.SendInvitationEmail`
5. **User clicks link** → Routes to acceptance page
6. **User accepts** → `accept_invitation/1` + Create `WorkspaceUser` record

### Security

- **Token Generation**: Cryptographically secure 32-byte random tokens
- **Token Storage**: Tokens are hashed with Bcrypt before storage
- **Time Limits**: Invitations expire after 7 days (configurable)
- **Email Validation**: Prevents duplicate invitations per workspace
- **Role Isolation**: Users can have different roles in different workspaces

## Customization

### Custom Email Templates

```elixir
# config/config.exs
config :ash_workspace, AshWorkspace.Senders.InvitationEmail,
  subject: fn workspace_name -> "Join #{workspace_name} on MyApp!" end,
  html_body: &MyApp.EmailTemplates.invitation_html/2,
  text_body: &MyApp.EmailTemplates.invitation_text/2
```

### Custom Password Requirements

```elixir
config :ash_workspace, :password_requirements,
  min_length: 12,
  require_uppercase: true,
  require_lowercase: true,
  require_digit: true,
  require_special: true
```

### Custom Roles

Edit your generated `WorkspaceUser` resource:

```elixir
attribute :role, :atom do
  allow_nil? false
  public? true
  default :member
  constraints one_of: [:owner, :admin, :member, :viewer, :billing, :guest]
end
```

### Custom Invitation Sender

```elixir
defmodule MyApp.CustomInvitationSender do
  def send(invitation, token, _context) do
    # Your custom email logic
    MyApp.SlackNotifier.send_invitation_notification(invitation)
    MyApp.Mailer.send_custom_invite(invitation, token)
  end
end

# Configure it
config :ash_workspace,
  invitation_sender: MyApp.CustomInvitationSender
```

## Module Reference

### Changes

- `AshWorkspace.Changes.SetToken` - Generates secure invitation tokens
- `AshWorkspace.Changes.CreateDefaultWorkspace` - Auto-creates workspace on user registration

### Validators

- `AshWorkspace.Validators.EmailUniquenessInWorkspace` - Prevents duplicate invitations
- `AshWorkspace.Validators.StrongPasswordValidation` - Enforces password strength

### Hooks

- `AshWorkspace.Hooks.SendInvitationEmail` - Sends invitation emails after creation

### Senders

- `AshWorkspace.Senders.InvitationEmail` - Default email sender with customizable templates

### Resources (Templates)

- `AshWorkspace.Resources.Workspace` - Documentation and reference
- `AshWorkspace.Resources.WorkspaceUser` - Documentation and reference
- `AshWorkspace.Resources.Invitation` - Documentation and reference

## Configuration Reference

### Required Configuration

```elixir
config :ash_workspace,
  domain: MyApp.Accounts,                          # Your Ash domain
  workspace_user_resource: MyApp.Accounts.WorkspaceUser,
  invitation_resource: MyApp.Accounts.Invitation,
  mailer: MyApp.Mailer,                           # Swoosh mailer
  from_email: {"MyApp", "noreply@myapp.com"},     # From address
  url_builder: &MyAppWeb.Router.Helpers.invitation_url/3  # URL builder function
```

### Optional Configuration

```elixir
config :ash_workspace,
  app_name: "MyApp",                              # Default: "Workspace"
  invitation_sender: MyApp.CustomSender,          # Default: AshWorkspace.Senders.InvitationEmail
  password_requirements: [                        # Password validation rules
    min_length: 10,
    require_uppercase: true,
    require_lowercase: true,
    require_digit: true,
    require_special: true
  ]
```

## Examples

### User Registration with Workspace

```elixir
{:ok, user} = MyApp.Accounts.register_with_password(%{
  email: "founder@acme.com",
  password: "SecureP@ss123",
  password_confirmation: "SecureP@ss123",
  workspace_name: "Acme Corp"
})

# User and workspace are created together
# User is automatically admin of the workspace
```

### Team Management

```elixir
# List workspace members
{:ok, members} = MyApp.Accounts.get_workspace_users_by_workspace_id(workspace.id)

# Update member role
{:ok, updated} = MyApp.Accounts.update_workspace_user(workspace_user, %{role: :admin})

# Remove member
{:ok, _} = MyApp.Accounts.destroy_workspace_user(workspace_user)
```

### Invitation Management

```elixir
# List pending invitations
{:ok, invitations} = MyApp.Accounts.get_all_pending_invitations()

# Resend invitation
{:ok, invitation} = MyApp.Accounts.resend_invitation(invitation)

# Revoke invitation
{:ok, invitation} = MyApp.Accounts.revoke_invitation(invitation)
```

## Documentation

Full documentation is available at [hexdocs.pm/ash_workspace](https://hexdocs.pm/ash_workspace).

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

Created by the Ash community. Inspired by common multi-tenancy patterns in SaaS applications.

## Support

- [Documentation](https://hexdocs.pm/ash_workspace)
- [GitHub Issues](https://github.com/your-org/ash_workspace/issues)
- [Ash Framework Discord](https://discord.gg/ash)

