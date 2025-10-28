defmodule __MODULE_PREFIX__.Accounts.Invitation.Senders.SendInvitationEmail do
  @moduledoc """
  Sends an invitation email to a new team member.
  """
  use AshAuthentication.Sender
  use __MODULE_PREFIX__Web, :verified_routes

  import Swoosh.Email
  alias __MODULE_PREFIX__.Mailer

  @impl true
  def send(invitation, token, _context) do
    url = url(~p"/invitation/accept/#{invitation.email}/#{token}")
    workspace_name = get_workspace_name(invitation)

    new()
    |> from({"__OTP_APP__", "noreply@__OTP_APP__.example.com"})
    |> to(to_string(invitation.email))
    |> subject("You're invited to join #{workspace_name}")
    |> html_body("""
    <div style="font-family: Arial, sans-serif; padding: 20px; color: black;">
      <h2 style="color: black;">You've been invited to join <span style="color: blue;">#{workspace_name}</span></h2>
      <p>
        Hello,<br/>
        You've been invited to join the workspace <strong>#{workspace_name}</strong>.
      </p>
      <p>
        Click the button below to accept the invitation and set up your account:
      </p>
      <a href="#{url}" style="
        display: inline-block;
        padding: 12px 20px;
        margin-top: 10px;
        background-color: blue;
        color: white;
        text-decoration: none;
        border-radius: 6px;
        font-weight: bold;
      ">
        Accept Invitation
      </a>
      <p style="margin-top: 20px; font-size: 13px; color: gray;">
        If you did not expect this email, you can ignore it.
      </p>
    </div>
    """)
    |> Mailer.deliver!()
  end

  defp get_workspace_name(invitation) do
    case __MODULE_PREFIX__.Accounts.get_workspace_by_id(invitation.workspace_id) do
      {:ok, workspace} when is_map(workspace) -> workspace.name
      {:ok, nil} -> "Workspace"
    end
  end
end
