defmodule __MODULE_PREFIX__Web.AuthLive.Register do
  use __MODULE_PREFIX__Web, :live_view
  alias __MODULE_PREFIX__.Accounts.User
  import __MODULE_PREFIX__Web.AuthLive.Components

  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-center items-center h-full bg-white">
      <p class="text-blue-800 font-bold text-4xl">Register</p>

      <.form
        id="registration-form"
        for={@form}
        phx-change="validate"
        phx-submit="submit"
        method="post"
        class="mt-4 space-y-3 w-80 flex flex-col justify-center"
      >
        <.input
          field={@form[:email]}
          type="email"
          id="user_email"
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
        <.input
          field={@form[:password_confirmation]}
          id="user_password_confirmation"
          type="password"
          label="Password Confirmation"
          placeholder="Confirm your password"
          required
        />
        <.input
          field={@form[:workspace_name]}
          id="user_workspace_name"
          type="text"
          label="Workspace Name"
          placeholder="Your workspace name"
          required
          oninput="this.value = this.value.trimStart()"
        />
        <button
          type="submit"
          class="w-[80%] self-center bg-black text-white text-sm py-2 rounded-lg hover:bg-gray-400 hover:text-black pt-3"
        >
          Create Workspace & Continue
        </button>
      </.form>

      <.register_footer />
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
