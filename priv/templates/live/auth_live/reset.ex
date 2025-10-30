defmodule __MODULE_PREFIX__Web.AuthLive.Reset do
  use __MODULE_PREFIX__Web, :live_view
  alias __MODULE_PREFIX__.Accounts.User
  import __MODULE_PREFIX__Web.AuthLive.Components

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 flex items-center justify-center p-4">
      <div class="card w-full max-w-md bg-base-100 shadow-xl">
        <div class="card-body">
          <h1 class="card-title text-3xl font-bold text-center justify-center mb-2">Reset Password</h1>
          <p class="text-center text-base-content/70 mb-4">Enter your email to receive a reset link</p>

          <.form
            id="password-reset-form"
            for={@form}
            phx-change="validate"
            phx-submit="submit"
            method="post"
            class="space-y-4"
          >
            <.input
              field={@form[:email]}
              type="email"
              label="Email"
              placeholder="Enter your email"
              autocomplete="email"
              required
              oninput="this.value = this.value.toLowerCase()"
            />
            <button type="submit" class="btn btn-primary w-full">
              Send Password Reset Email
            </button>
          </.form>

          <.register_footer />
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    form =
      AshPhoenix.Form.for_action(User, :request_password_reset_token, domain: Accounts)
      |> to_form()

    {:ok, assign(socket, form: form)}
  end

  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("submit", %{"form" => form_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: form_params) do
      :ok ->
        {:noreply,
         socket
         |> push_navigate(to: "/sign-in")
         |> put_flash(:info, "Password reset token has been sent to to your email address")}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to send password reset token")}
    end
  end
end
