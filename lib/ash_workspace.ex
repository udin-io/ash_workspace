defmodule AshWorkspace do
  @moduledoc """
  Multi-tenancy workspace and invitation system for Ash Framework applications.

  AshWorkspace provides a complete solution for adding workspace-based multi-tenancy
  to your Ash application, including:

  - **Workspace Management**: Organize users into isolated workspaces
  - **Invitation System**: Invite users via email with secure token-based links
  - **Role-Based Access Control**: Assign roles (admin, member, billing, etc.)
  - **Email Integration**: Automatic invitation emails with customizable templates
  - **Security**: Bcrypt-hashed tokens, time-limited invitations
  - **Flexibility**: Fully customizable resources, validators, and email senders

  ## Installation

  Add `ash_workspace` to your dependencies in `mix.exs`:

      def deps do
        [
          {:ash_workspace, "~> 0.1.0"}
        ]
      end

  Then run:

      mix deps.get
      mix ash_workspace.install

  ## Quick Start

  After installation, configure your application:

      # config/config.exs
      config :ash_workspace,
        domain: MyApp.Accounts,
        workspace_user_resource: MyApp.Accounts.WorkspaceUser,
        invitation_resource: MyApp.Accounts.Invitation,
        mailer: MyApp.Mailer,
        from_email: {"MyApp Team", "noreply@myapp.com"},
        app_name: "MyApp",
        url_builder: &MyAppWeb.Router.Helpers.invitation_acceptance_url/3

  The installer will generate:
  - Workspace, WorkspaceUser, and Invitation resources
  - Database migrations
  - User resource modifications to support workspaces

  ## Core Concepts

  ### Workspaces

  Workspaces are the top-level multi-tenancy containers. Each workspace can have
  multiple users, and users can belong to multiple workspaces.

  ### WorkspaceUser (Join Table)

  The WorkspaceUser resource connects users to workspaces with a role attribute,
  enabling role-based access control per workspace.

  ### Invitations

  Invitations allow workspace admins to invite new users by email. Features include:
  - Secure token generation and hashing
  - Configurable expiration (default 7 days)
  - Email validation (no duplicates per workspace)
  - Automatic email delivery
  - Status tracking (created, accepted, revoked)

  ## Architecture

  AshWorkspace uses a **template-based code generation** approach:

  - **Shared Code**: Only `AshWorkspace.Changes.SetToken` is shared across projects
  - **Generated Code**: All resources, validators, senders, and LiveViews are generated
    from templates into your project during installation
  - **Full Control**: Generated code becomes part of your codebase, fully customizable

  ## Generated Modules

  The installer generates these modules in your project:

  ### Resources
  - `YourApp.Accounts.Workspace` - Workspace resource
  - `YourApp.Accounts.WorkspaceUser` - Join table with role attribute
  - `YourApp.Accounts.Invitation` - Invitation resource with token handling

  ### Changes & Validators
  - `YourApp.Accounts.Changes.CreateDefaultWorkspace` - Auto-create workspace on signup
  - `YourApp.Accounts.Validators.EmailUniquenessInWorkspace` - Prevent duplicate invitations
  - `YourApp.Accounts.Validators.StrongPasswordValidation` - Enforce password requirements

  ### Email Senders
  - `YourApp.Accounts.Invitation.Senders.SendInvitationEmail` - Invitation email sender
  - `YourApp.Accounts.User.Senders.SendNewUserConfirmationEmail` - User confirmation
  - `YourApp.Accounts.User.Senders.SendPasswordResetEmail` - Password reset

  ### LiveViews
  - `YourAppWeb.WorkspaceLive.Index` - Workspace list (default landing page)
  - `YourAppWeb.TeamLive.Index` - Team management for workspace admins
  - `YourAppWeb.AuthLive.*` - Authentication pages (register, sign-in, reset)
  - `YourAppWeb.InvitationAcceptanceLive.*` - Invitation acceptance flow

  ## Customization

  Every aspect of AshWorkspace can be customized:

  ### Custom Email Templates

      config :ash_workspace, AshWorkspace.Senders.InvitationEmail,
        subject: fn workspace_name -> "Join \#{workspace_name}" end,
        html_body: &MyApp.EmailTemplates.invitation_html/2

  ### Custom Validators

  Replace or extend validators in your resources:

      validate MyApp.CustomEmailValidator

  ### Custom Invitation Sender

  Implement your own sender:

      defmodule MyApp.CustomSender do
        def send(invitation, token, _context) do
          # Custom logic
        end
      end

      # Configure it
      config :ash_workspace,
        invitation_sender: MyApp.CustomSender

  ## Examples

  ### Creating a Workspace

      MyApp.Accounts.create_workspace(%{name: "Acme Corp"})

  ### Inviting a User

      MyApp.Accounts.create_invitation(%{
        email: "user@example.com",
        role: :member,
        workspace_id: workspace_id,
        user_id: inviter_user_id
      })

  ### Accepting an Invitation

      MyApp.Accounts.accept_invitation(invitation)

  ## Configuration Reference

  Required configuration keys:

  - `:domain` - Your Ash domain module (e.g., `MyApp.Accounts`)
  - `:workspace_user_resource` - WorkspaceUser resource module
  - `:invitation_resource` - Invitation resource module
  - `:mailer` - Your Swoosh mailer module
  - `:from_email` - From address for invitation emails
  - `:url_builder` - Function to build invitation acceptance URLs

  Optional configuration:

  - `:app_name` - Application name for email templates (default: "Workspace")
  - `:invitation_sender` - Custom email sender module
  - `:password_requirements` - Custom password validation rules

  ## Learn More

  - [Installation Guide](https://hexdocs.pm/ash_workspace/installation.html)
  - [Customization Guide](https://hexdocs.pm/ash_workspace/customization.html)
  - [API Reference](https://hexdocs.pm/ash_workspace/api-reference.html)
  """

  @doc false
  def version, do: unquote(Mix.Project.config()[:version])
end
