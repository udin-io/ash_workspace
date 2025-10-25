defmodule AshWorkspace.Senders.InvitationEmail do
  @moduledoc """
  Default email sender for workspace invitations.

  This module provides a basic invitation email template that can be customized
  or completely replaced in your application.

  ## Configuration

  Required configuration in your application:

      config :ash_workspace,
        domain: MyApp.Accounts,
        mailer: MyApp.Mailer,
        from_email: {"Your App Team", "noreply@yourapp.com"},
        app_name: "Your App",
        url_builder: &MyAppWeb.Router.Helpers.invitation_acceptance_url/3

  ## Customization

  ### Option 1: Override the template

  You can customize the email appearance by configuring template options:

      config :ash_workspace, AshWorkspace.Senders.InvitationEmail,
        subject: fn workspace_name -> "Join \#{workspace_name} on MyApp" end,
        html_body: &MyApp.EmailTemplates.invitation_html/2,
        text_body: &MyApp.EmailTemplates.invitation_text/2

  ### Option 2: Create your own sender

  Create a custom module that implements the `send/3` callback:

      defmodule MyApp.InvitationSender do
        use AshAuthentication.Sender

        @impl true
        def send(invitation, token, _context) do
          # Custom email logic
        end
      end

  Then use it in your Invitation resource:

      change after_action(&MyApp.InvitationSender.send_email/3)

  ## URL Builder

  The URL builder function receives:
  - `email` - The invitation email address
  - `token` - The raw invitation token
  - `invitation` - The full invitation record (for additional context)

  And should return the full acceptance URL as a string.

  Example:

      def build_invitation_url(email, token, _invitation) do
        MyAppWeb.Router.Helpers.invitation_acceptance_url(
          MyAppWeb.Endpoint,
          :show,
          email,
          token
        )
      end
  """

  @doc false
  def send(invitation, token, _context \\ %{}) do
    if swoosh_available?() do
      do_send(invitation, token)
    else
      raise """
      Swoosh is not available. Either:

      1. Add {:swoosh, "~> 1.14"} to your dependencies
      2. Implement a custom invitation sender
      3. Configure a different sender in your Invitation resource
      """
    end
  end

  defp do_send(invitation, token) do
    import Swoosh.Email

    config = get_config()
    workspace_name = get_workspace_name(invitation, config)
    url = build_url(invitation.email, token, invitation, config)

    subject = get_subject(workspace_name, config)
    html = get_html_body(workspace_name, url, config)

    new()
    |> from(config.from_email)
    |> to(to_string(invitation.email))
    |> subject(subject)
    |> html_body(html)
    |> maybe_add_text_body(workspace_name, url, config)
    |> deliver(config.mailer)
  end

  defp get_config do
    %{
      domain: get_required_config!(:domain),
      mailer: get_required_config!(:mailer),
      from_email: get_required_config!(:from_email),
      app_name: Application.get_env(:ash_workspace, :app_name, "Workspace"),
      url_builder: get_required_config!(:url_builder),
      subject_fn: Application.get_env(:ash_workspace, __MODULE__, [])[:subject],
      html_body_fn: Application.get_env(:ash_workspace, __MODULE__, [])[:html_body],
      text_body_fn: Application.get_env(:ash_workspace, __MODULE__, [])[:text_body]
    }
  end

  defp get_required_config!(key) do
    Application.get_env(:ash_workspace, key) ||
      raise """
      AshWorkspace configuration missing for #{inspect(key)}.

      Please add to your config:

          config :ash_workspace,
            domain: MyApp.Accounts,
            mailer: MyApp.Mailer,
            from_email: {"Your App", "noreply@yourapp.com"},
            url_builder: &MyAppWeb.invitation_url/3
      """
  end

  defp get_workspace_name(invitation, config) do
    case config.domain.get_workspace_by_id(invitation.workspace_id,
           actor: nil,
           authorize?: false
         ) do
      {:ok, workspace} when is_map(workspace) -> workspace.name
      _ -> "Workspace"
    end
  end

  defp build_url(email, token, invitation, config) do
    config.url_builder.(email, token, invitation)
  end

  defp get_subject(workspace_name, config) do
    if config.subject_fn do
      config.subject_fn.(workspace_name)
    else
      "You're invited to join #{workspace_name}"
    end
  end

  defp get_html_body(workspace_name, url, config) do
    if config.html_body_fn do
      config.html_body_fn.(workspace_name, url)
    else
      default_html_body(workspace_name, url, config.app_name)
    end
  end

  defp default_html_body(workspace_name, url, app_name) do
    """
    <div style="font-family: Arial, sans-serif; padding: 20px; color: black;">
      <h2 style="color: black;">You've been invited to join <span style="color: #4F46E5;">#{workspace_name}</span></h2>
      <p>
        Hello,<br/>
        You've been invited to join the workspace <strong>#{workspace_name}</strong> on #{app_name}.
      </p>
      <p>
        Click the button below to accept the invitation and set up your account:
      </p>
      <a href="#{url}" style="
        display: inline-block;
        padding: 12px 20px;
        margin-top: 10px;
        background-color: #4F46E5;
        color: white;
        text-decoration: none;
        border-radius: 6px;
        font-weight: bold;
      ">
        Accept Invitation
      </a>
      <p style="margin-top: 20px; font-size: 13px; color: #6B7280;">
        If you did not expect this email, you can safely ignore it.
      </p>
    </div>
    """
  end

  defp maybe_add_text_body(email, workspace_name, url, config) do
    if config.text_body_fn do
      import Swoosh.Email
      text_body(email, config.text_body_fn.(workspace_name, url))
    else
      email
    end
  end

  defp deliver(email, mailer) do
    mailer.deliver!(email)
  end

  defp swoosh_available? do
    Code.ensure_loaded?(Swoosh.Email)
  end
end
