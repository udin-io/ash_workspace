defmodule __MODULE_PREFIX__.Accounts.User.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends a password reset email
  """

  use AshAuthentication.Sender
  use __MODULE_PREFIX__Web, :verified_routes

  import Swoosh.Email

  alias __MODULE_PREFIX__.Mailer

  @impl true
  def send(user, token, _) do
    new()
    |> from({"__OTP_APP__", "noreply@__OTP_APP__.example.com"})
    |> to(to_string(user.email))
    |> subject("Reset your password")
    |> html_body(body(token: token))
    |> Mailer.deliver!()
  end

  defp body(params) do
    url = url(~p"/password-reset/#{params[:token]}")

    """
    <p>Click this link to reset your password:</p>
    <p><a href="#{url}">#{url}</a></p>
    """
  end
end
