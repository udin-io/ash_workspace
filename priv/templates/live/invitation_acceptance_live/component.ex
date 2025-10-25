defmodule __MODULE_PREFIX__Web.InvitationAcceptanceAuthLive.Components do
  @moduledoc """
  This module contains reusable components and helper functions for the invitation acceptance LiveViews.
  It includes form components for registration and sign-in, footer components, input helpers,
  and authentication-related functions.
  """
  use __MODULE_PREFIX__Web, :live_view

  ### FORM COMPONENTS

  def register_form(assigns) do
    ~H"""
    <.form
      id="registration-form"
      for={@form}
      phx-change="validate"
      phx-submit="submit"
      method="post"
      class="mt-4 space-y-3 w-80 flex flex-col justify-center"
    >
      <.readonly_email_input form={@form} email={@invitation.email} />
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
      <.submit_button id="register-submit-button" text="Create account & Continue" />
    </.form>
    """
  end

  def sign_in_form(assigns) do
    ~H"""
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
      <.readonly_email_input form={@form} email={@invitation.email} />
      <.input
        field={@form[:password]}
        id="user_password"
        type="password"
        label="Password"
        placeholder="Enter your password"
        required
      />
      <div class="pt-3">
        <.submit_button text="Sign In" id="sign-in-submit-button" />
      </div>
    </.form>
    """
  end

  ### FOOTER COMPONENTS

  def sign_in_footer(assigns) do
    ~H"""
    <.footer_wrapper>
      <div class="flex justify-between text-sm text-gray-600">
        <p>
          Don't have an account?
          <.link
            navigate={~p"/invitation/accept/register/#{@email}/#{@token}"}
            class="text-black font-medium hover:underline"
          >
            Register
          </.link>
        </p>
        <p></p>
      </div>
    </.footer_wrapper>
    """
  end

  def register_footer(assigns) do
    ~H"""
    <.footer_wrapper>
      <p class="text-sm text-gray-600">
        Already have an account?
        <.link
          navigate={~p"/invitation/accept/sign-in/#{@email}/#{@token}"}
          class="text-black font-medium hover:underline"
        >
          Sign in
        </.link>
      </p>
    </.footer_wrapper>
    """
  end

  def footer_wrapper(assigns) do
    ~H"""
    <div class="w-80 mt-6 text-center">
      <hr class="border-gray-300 mb-4" />
      {render_slot(@inner_block)}
    </div>
    """
  end

  ### INPUT + BUTTON HELPERS

  defp readonly_email_input(assigns) do
    ~H"""
    <.input
      field={@form[:email]}
      value={@email}
      type="email"
      id="user_email"
      label="Email"
      placeholder="Enter your email"
      required
      readonly
      oninput="this.value = this.value.toLowerCase()"
    />
    """
  end

  defp submit_button(assigns) do
    ~H"""
    <button
      type="submit"
      id={@id}
      class="w-[80%] self-center bg-black text-white text-sm py-2 rounded-lg hover:bg-gray-400 hover:text-black"
    >
      {@text}
    </button>
    """
  end

  ### AUTH HELPERS

  def verify_token(raw_token, hashed_token) do
    Bcrypt.verify_pass(raw_token, hashed_token)
  end

  def assign_to_workspace(user_id, invitation) do
    __MODULE_PREFIX__.Accounts.accept_invitation(invitation.id)

    case __MODULE_PREFIX__.Accounts.create_workspace_user(invitation.role, invitation.workspace_id, user_id) do
      {:ok, _workspace} -> {:ok, "You have been successfully added to the workspace."}
      {:error, _} -> {:error, "Failed to add you to the workspace."}
    end
  end

  def put_flash_from_result(socket, {:ok, msg}),
    do: put_flash(socket, :info, msg)

  def put_flash_from_result(socket, {:error, msg}),
    do: put_flash(socket, :error, msg)
end
