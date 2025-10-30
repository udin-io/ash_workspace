defmodule __MODULE_PREFIX__Web.InvitationAcceptanceAuthLive.RegisterIndex do
  @moduledoc """
  LiveView for handling user registration during invitation acceptance.
  """
  use __MODULE_PREFIX__Web, :live_view

  alias __MODULE_PREFIX__.Accounts
  import __MODULE_PREFIX__Web.InvitationAcceptanceAuthLive.Components

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 flex items-center justify-center p-4">
      <div class="card w-full max-w-md bg-base-100 shadow-xl">
        <div class="card-body">
          <Layouts.flash_group flash={@flash} />
          <h1 class="card-title text-3xl font-bold text-center justify-center mb-2">Accept Invitation</h1>
          <p class="text-center text-base-content/70 mb-4">Create your account to join the workspace</p>
          <.register_form form={@form} invitation={@invitation} />
          <.register_footer email={@invitation.email} token={@raw_token} />
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"email" => encoded_email, "token" => raw_token} = params, _session, socket) do
    email = URI.decode(encoded_email)
    socket = maybe_put_flash(socket, params["flash"])

    with {:ok, invitation} <- Accounts.get_pending_invitations_by_email(email),
         true <- verify_token(raw_token, invitation.token) do
      form =
        Accounts.User
        |> AshPhoenix.Form.for_create(:register_with_password, domain: Accounts)
        |> to_form()

      {:ok, assign(socket, invitation: invitation, raw_token: raw_token, form: form)}
    else
      false ->
        {:ok,
         socket
         |> put_flash(:error, "Invalid invitation token.")
         |> redirect(to: "/")}

      {:error, _reason} ->
        {:ok,
         socket
         |> put_flash(:error, "No pending invitation found for this email.")
         |> redirect(to: "/")}
    end
  end

  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("submit", %{"form" => form_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: form_params) do
      {:ok, user} ->
        result = assign_to_workspace(user.id, socket.assigns.invitation)

        {:noreply,
         socket
         |> put_flash_from_result(result)
         |> push_navigate(to: "/sign-in")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp maybe_put_flash(socket, nil), do: socket
  defp maybe_put_flash(socket, msg), do: put_flash(socket, :info, URI.decode(msg))
end
