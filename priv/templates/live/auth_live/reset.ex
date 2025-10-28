defmodule __MODULE_PREFIX__Web.AuthLive.Reset do
  use __MODULE_PREFIX__Web, :live_view
  alias __MODULE_PREFIX__.Accounts.User
  import __MODULE_PREFIX__Web.AuthLive.Components

  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-center items-center h-full bg-white">
      <p class="text-blue-800 font-bold text-4xl">Reset Password</p>

      <.form
        id="password-reset-form"
        for={@form}
        phx-change="validate"
        phx-submit="submit"
        method="post"
        class="mt-4 space-y-3 w-80 flex flex-col justify-center"
      >
        <.input
          field={@form[:email]}
          type="email"
          label="Email"
          placeholder="Enter your email"
          required
          oninput="this.value = this.value.toLowerCase()"
        />
        <button
          type="submit"
          class="w-[80%] self-center bg-black text-white text-sm py-2 rounded-lg hover:bg-gray-400 hover:text-black pt-3"
        >
          Send password reset mail
        </button>
      </.form>

      <.register_footer />
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
