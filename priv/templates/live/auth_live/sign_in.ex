defmodule __MODULE_PREFIX__Web.AuthLive.SignIn do
  use __MODULE_PREFIX__Web, :live_view
  alias __MODULE_PREFIX__.Accounts.User
  import __MODULE_PREFIX__Web.AuthLive.Components

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 flex items-center justify-center p-4">
      <div class="card w-full max-w-md bg-base-100 shadow-xl">
        <div class="card-body">
          <h1 class="card-title text-3xl font-bold text-center justify-center mb-2">Welcome Back</h1>
          <p class="text-center text-base-content/70 mb-4">Sign in to your workspace</p>

          <.form
            id="sign-in-form"
            for={@form}
            phx-change="validate"
            phx-submit="submit"
            phx-trigger-action={@trigger_action}
            action={@action}
            method="post"
            class="space-y-4"
          >
            <.input
              field={@form[:email]}
              id="user_email"
              type="email"
              label="Email"
              placeholder="Enter your email"
              autocomplete="email"
              required
              oninput="this.value = this.value.toLowerCase()"
            />
            <.input
              field={@form[:password]}
              id="user_password"
              type="password"
              label="Password"
              placeholder="Enter your password"
              autocomplete="off"
              required
            />
            <button type="submit" id="sign-in-submit-button" class="btn btn-primary w-full">
              Sign In
            </button>
          </.form>

          <.sign_in_footer />
        </div>
      </div>
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
