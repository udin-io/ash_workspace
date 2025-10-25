defmodule __MODULE_PREFIX__Web.AuthLive.SignIn do
  use __MODULE_PREFIX__Web, :live_view
  alias __MODULE_PREFIX__.Accounts.User
  import __MODULE_PREFIX__Web.AuthLive.Components

  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-center items-center h-full bg-white">
      <p class="text-blue-800 font-bold text-4xl">Sign-In</p>
      <.form
        id="sign-in-form"
        for={@form}
        phx-change="validate"
        phx-submit="submit"
        phx-trigger-action={@trigger_action}
        action={@action}
        method="post"
        class="mt-4 space-y-3"
      >
        <.input
          field={@form[:email]}
          id="user_email"
          type="email"
          label="Email"
          placeholder="Enter your email"
          required
          oninput="this.value = this.value.toLowerCase()"
        />
        <.input
          field={@form[:password]}
          id="user_password"
          type="password"
          label="Password"
          placeholder="Enter your password"
          required
        />
        <div class="pt-3">
          <button
            type="submit"
            id="sign-in-submit-button"
            class="w-52 bg-black text-white text-sm py-2 rounded-lg  hover:bg-gray-400 hover:text-black "
          >
            Sign In
          </button>
        </div>
      </.form>

      <.sign_in_footer />
    </div>
    """
  end

  def mount(_params, _session, socket) do
    form =
      AshPhoenix.Form.for_action(User, :sign_in_with_password, domain: __MODULE_PREFIX__.Accounts, as: "user")
      |> to_form()

    {:ok,
     socket
     |> assign(
       form: form,
       action: ~p"/auth/user/password/sign_in",
       trigger_action: false
     )}
  end

  def handle_event("validate", %{"user" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("submit", %{"user" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _user} ->
        socket =
          socket
          |> assign(:form, socket.assigns.form)
          |> assign(:trigger_action, true)

        {:noreply, socket}

      {:error, form} ->
        socket =
          socket
          |> assign(:form, form)

        {:noreply, socket}
    end
  end
end
