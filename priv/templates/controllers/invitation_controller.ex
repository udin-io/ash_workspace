defmodule __MODULE_PREFIX__Web.InvitationController do
  @moduledoc """
  Handles the acceptance of invitations to join a workspace.
  This controller processes the invitation acceptance flow, including verifying the invitation token,
  checking if the user is already signed in, and redirecting to the appropriate pages for registration
  or auto-accepting the invitation if the user is signed in with the same email.
  It also handles cases where the user is signed in with a different email, logging them out and
  redirecting them to the registration page.
  """

  use __MODULE_PREFIX__Web, :controller

  alias __MODULE_PREFIX__.Accounts
  alias __MODULE_PREFIX__Web.InvitationAcceptanceAuthLive.Components

  def accept(conn, %{"email" => email, "token" => token}) do
    decoded_email = URI.decode(email)
    current_user = conn.assigns[:current_user]

    with {:ok, invitation} <- Accounts.get_pending_invitations_by_email(decoded_email),
         true <- Components.verify_token(token, invitation.token) do
      handle_invitation(conn, invitation, current_user, email, token)
    else
      {:error, _reason} ->
        redirect_to_landing(conn, :error, "Invitation not found.")

      false ->
        redirect_to_landing(conn, :error, "Invalid or expired invitation token.")
    end
  end

  defp handle_invitation(conn, invitation, nil, email, token) do
    # Check if user with this email already exists
    case __MODULE_PREFIX__.Accounts.User.get_by_email(invitation.email) do
      {:ok, _user} ->
        # User exists - redirect to sign-in
        redirect_to_sign_in(conn, email, token, "Please sign in to accept your invitation.")

      {:error, _} ->
        # User doesn't exist - redirect to register
        redirect_to_register(conn, email, token, "Please register to continue with your invitation.")
    end
  end

  defp handle_invitation(
         conn,
         %{email: invitation_email} = invitation,
         %{email: user_email} = user,
         _email,
         _token
       )
       when user_email == invitation_email do
    case Components.assign_to_workspace(user, invitation) do
      {:ok, msg} -> redirect_to_landing(conn, :info, msg)
      {:error, reason} -> redirect_to_landing(conn, :error, reason)
    end
  end

  defp handle_invitation(conn, _invitation, _user, email, token) do
    conn
    |> configure_session(drop: true)
    |> redirect_to_register(
      email,
      token,
      "You were signed in as a different user. Please register or sign in again with the correct account."
    )
  end

  defp redirect_to_landing(conn, type, msg) do
    conn
    |> put_flash(type, msg)
    |> redirect(to: "/")
  end

  defp redirect_to_register(conn, email, token, message) do
    conn
    |> redirect(to: ~p"/invitation/accept/register/#{email}/#{token}?flash=#{message}")
  end

  defp redirect_to_sign_in(conn, email, token, message) do
    conn
    |> redirect(to: ~p"/invitation/accept/sign-in/#{email}/#{token}?flash=#{message}")
  end
end
