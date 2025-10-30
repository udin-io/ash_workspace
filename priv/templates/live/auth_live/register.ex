defmodule __MODULE_PREFIX__Web.AuthLive.Register do
  use __MODULE_PREFIX__Web, :live_view
  alias __MODULE_PREFIX__.Accounts.User
  import __MODULE_PREFIX__Web.AuthLive.Components

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 flex items-center justify-center p-4">
      <div class="card w-full max-w-md bg-base-100 shadow-xl">
        <div class="card-body">
          <h1 class="card-title text-3xl font-bold text-center justify-center mb-2">Create Account</h1>
          <p class="text-center text-base-content/70 mb-4">Sign up to create your workspace</p>

          <.form
            id="registration-form"
            for={@form}
            phx-change="validate"
            phx-submit="submit"
            method="post"
            class="space-y-4"
          >
            <.input
              field={@form[:email]}
              type="email"
              id="user_email"
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
            <.input
              field={@form[:password_confirmation]}
              id="user_password_confirmation"
              type="password"
              label="Password Confirmation"
              placeholder="Confirm your password"
              autocomplete="off"
              required
            />
            <.input
              field={@form[:workspace_name]}
              id="user_workspace_name"
              type="text"
              label="Workspace Name"
              placeholder="Your workspace name"
              autocomplete="organization"
              required
              oninput="this.value = this.value.trimStart()"
            />
            <button type="submit" class="btn btn-primary w-full">
              Create Workspace & Continue
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
      AshPhoenix.Form.for_create(User, :register_with_password, domain: __MODULE_PREFIX__.Accounts)
      |> to_form()

    {:ok, assign(socket, form: form)}
  end

  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("submit", %{"form" => form_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: form_params) do
      {:ok, _} ->
        {:noreply, push_navigate(socket, to: "/sign-in")}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end
end
