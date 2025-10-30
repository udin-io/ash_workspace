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
- Generate LiveViews for workspace list, team management, auth pages
- Generate email senders for invitations, confirmations, password resets
- Generate validators and change modules
- Create database migrations
- Update your User resource with workspace relationships and password authentication
- Add router routes for authentication and team management

## Quick Start

### 1. Run migrations

```bash
mix ash.setup
```

### 2. Start your server

```bash
mix phx.server
```

Visit `http://localhost:4000/register` to create your first workspace!

### 3. Using workspaces in code

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

### Template-Based Code Generation

AshWorkspace uses a **template-based approach** - instead of providing pre-built modules, it generates all code into your project during installation:

- **✅ Full Control**: All generated code becomes part of your codebase
- **✅ Easy Customization**: Edit generated files directly - they're yours
- **✅ No Hidden Dependencies**: Only `AshWorkspace.Changes.SetToken` is shared
- **✅ Type-Safe**: Generated code is tailored to your project's module structure

### Data Architecture

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

1. **Admin creates invitation** → `MyApp.Accounts.create_invitation/1`
2. **System generates token** → `AshWorkspace.Changes.SetToken` (shared module)
3. **System validates email** → `MyApp.Accounts.Validators.EmailUniquenessInWorkspace` (generated)
4. **System sends email** → `MyApp.Accounts.Invitation.Senders.SendInvitationEmail` (generated)
5. **User clicks link** → Routes to acceptance page (generated LiveView)
6. **User accepts** → `accept_invitation/1` + Create `WorkspaceUser` record

### Security

- **Token Generation**: Cryptographically secure 32-byte random tokens
- **Token Storage**: Tokens are hashed with Bcrypt before storage
- **Time Limits**: Invitations expire after 7 days (configurable)
- **Email Validation**: Prevents duplicate invitations per workspace
- **Role Isolation**: Users can have different roles in different workspaces

## Customization

Since all code is generated into your project, customization is straightforward - just edit the generated files!

### Custom Email Templates

Edit `lib/my_app/accounts/invitation/senders/send_invitation_email.ex`:

```elixir
defmodule MyApp.Accounts.Invitation.Senders.SendInvitationEmail do
  # ...

  @impl true
  def send(invitation, token, _context) do
    url = url(~p"/invitation/accept/#{invitation.email}/#{token}")
    workspace_name = get_workspace_name(invitation)

    new()
    |> from({"MyApp Team", "noreply@myapp.com"})
    |> to(to_string(invitation.email))
    |> subject("Join #{workspace_name} on MyApp!")  # Customize here
    |> html_body("""
      <!-- Your custom HTML template -->
      <a href="#{url}">Accept Invitation</a>
    """)
    |> Mailer.deliver!()
  end
end
```

### Custom Roles

Edit `lib/my_app/accounts/workspace_user.ex`:

```elixir
attribute :role, :atom do
  allow_nil? false
  public? true
  default :member
  constraints one_of: [:owner, :admin, :member, :viewer, :billing, :guest]  # Add custom roles
end
```

### Custom Validators

Edit `lib/my_app/accounts/validators/email_uniqueness_in_workspace.ex` or create your own validator and reference it in the Invitation resource.

## Generated Files

After running `mix ash_workspace.install`, these files are created in your project:

### Resources (`lib/my_app/accounts/`)

- `workspace.ex` - Workspace resource
- `workspace_user.ex` - Join table with role attribute
- `invitation.ex` - Invitation resource with token handling

### Changes (`lib/my_app/accounts/changes/`)

- `create_default_workspace.ex` - Auto-creates workspace on user registration

### Validators (`lib/my_app/accounts/validators/`)

- `email_uniqueness_in_workspace.ex` - Prevents duplicate invitations
- `strong_password_validation.ex` - Enforces password strength

### Email Senders (`lib/my_app/accounts/`)

- `invitation/senders/send_invitation_email.ex` - Invitation emails
- `user/senders/send_new_user_confirmation_email.ex` - User confirmations
- `user/senders/send_password_reset_email.ex` - Password resets

### LiveViews (`lib/my_app_web/live/`)

- `workspace_live/index.ex` - Workspace list (default landing page)
- `team_live/index.ex` - Team management for admins
- `auth_live/*.ex` - Authentication pages (register, sign-in, reset)
- `invitation_acceptance_live/*.ex` - Invitation acceptance flow

### Shared Module (Package)

- `AshWorkspace.Changes.SetToken` - Token generation (only shared code)

## Routes Added

The installer adds these routes to your router:

- `GET /` - Workspace list (authenticated users)
- `GET /register` - User registration with workspace creation
- `GET /sign-in` - Sign in page
- `GET /reset` - Password reset page
- `GET /workspaces/:workspace_id/team` - Team management (workspace admins only)
- `GET /invitation/accept/:email/:token` - Invitation acceptance

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

## Screenshot

### Sign-up and Create Workspace

<img width="1323" height="1006" alt="Screenshot from 2025-10-30 12-56-14" src="https://github.com/user-attachments/assets/0c8a2741-c0eb-41a7-8990-4ddfa1edb0f0" />

### Sign-in 

<img width="1323" height="1006" alt="Screenshot from 2025-10-30 12-51-18" src="https://github.com/user-attachments/assets/9eb74500-e2aa-4380-9d48-69ed346fb099" />

### View your workspaces and see manage option if admin 

<img width="1323" height="1006" alt="Screenshot from 2025-10-30 12-51-36" src="https://github.com/user-attachments/assets/e5430c98-7524-4c65-a120-718d48aaa177" />

### Invite new members

<img width="1323" height="1006" alt="Screenshot from 2025-10-30 12-51-56" src="https://github.com/user-attachments/assets/ad4b1534-daf6-4a33-8416-788b56b46c3a" />

### Review pending invites

<img width="1323" height="1006" alt="Screenshot from 2025-10-30 12-52-03" src="https://github.com/user-attachments/assets/0219cdb2-3a1f-4ad1-9800-99dcec0fb56c" />

### Accept an invitation (and signup)

<img width="1323" height="1006" alt="Screenshot from 2025-10-30 12-52-37" src="https://github.com/user-attachments/assets/bedfbbba-8156-4f4d-b056-c220bf402698" />

### View workspaces you are a member of (as non-admin)

<img width="1323" height="1006" alt="Screenshot from 2025-10-30 12-53-06" src="https://github.com/user-attachments/assets/f2ec547d-76dc-4966-9503-b972f04733a6" />


