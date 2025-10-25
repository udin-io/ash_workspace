defmodule AshWorkspace.Hooks.SendInvitationEmail do
  @moduledoc """
  After-action hook to send invitation emails.

  This hook extracts the raw token from the changeset context
  (placed there by `AshWorkspace.Changes.SetToken`) and sends
  an invitation email using the configured sender.

  ## Usage

  In your Invitation resource:

      create :create do
        change AshWorkspace.Changes.SetToken
        change after_action(&AshWorkspace.Hooks.SendInvitationEmail.after_action/3)
      end

  ## Configuration

  Configure the email sender (defaults to `AshWorkspace.Senders.InvitationEmail`):

      config :ash_workspace,
        invitation_sender: MyApp.CustomInvitationSender

  The sender module must implement a `send/3` function that accepts:
  - `invitation` - The invitation record
  - `token` - The raw (unhashed) token
  - `context` - The changeset context map

  ## Custom Sender Example

      defmodule MyApp.CustomInvitationSender do
        def send(invitation, token, _context) do
          # Send email logic
          :ok
        end
      end
  """

  @doc """
  Sends an invitation email after the invitation is created or resent.

  Extracts the raw token from changeset context and delegates to the
  configured sender module.
  """
  def after_action(changeset, result, _opts) do
    raw_token = changeset.context[:raw_token]

    if raw_token do
      sender = get_sender()
      sender.send(result, raw_token, changeset.context)
    end

    {:ok, result}
  end

  defp get_sender do
    Application.get_env(
      :ash_workspace,
      :invitation_sender,
      AshWorkspace.Senders.InvitationEmail
    )
  end
end
