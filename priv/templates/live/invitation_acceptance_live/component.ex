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
      class="space-y-4"
    >
      <.readonly_email_input form={@form} email={@invitation.email} />
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
      <.submit_button id="register-submit-button" text="Create Account & Continue" />
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
      class="space-y-4"
    >
      <.readonly_email_input form={@form} email={@invitation.email} />
      <.input
        field={@form[:password]}
        id="user_password"
        type="password"
        label="Password"
        placeholder="Enter your password"
        autocomplete="off"
        required
      />
      <.submit_button text="Sign In" id="sign-in-submit-button" />
    </.form>
    """
  end

  ### FOOTER COMPONENTS

  def sign_in_footer(assigns) do
    ~H"""
    <.footer_wrapper>
      <div class="flex justify-center text-sm text-base-content/70">
        <p>
          Don't have an account?
          <.link
            navigate={~p"/invitation/accept/register/#{@email}/#{@token}"}
            class="link link-primary font-medium"
          >
            Register
          </.link>
        </p>
      </div>
    </.footer_wrapper>
    """
  end

  def register_footer(assigns) do
    ~H"""
    <.footer_wrapper>
      <p class="text-sm text-base-content/70">
        Already have an account?
        <.link
          navigate={~p"/invitation/accept/sign-in/#{@email}/#{@token}"}
          class="link link-primary font-medium"
        >
          Sign in
        </.link>
      </p>
    </.footer_wrapper>
    """
  end

  def footer_wrapper(assigns) do
    ~H"""
    <div class="mt-6 text-center">
      <div class="divider"></div>
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
      autocomplete="email"
      required
      readonly
      oninput="this.value = this.value.toLowerCase()"
    />
    """
  end

  defp submit_button(assigns) do
    ~H"""
    <button type="submit" id={@id} class="btn btn-primary w-full">
      {@text}
    </button>
    """
  end

  ### AUTH HELPERS

  def verify_token(raw_token, hashed_token) do
    Bcrypt.verify_pass(raw_token, hashed_token)
  end

  def assign_to_workspace(user, invitation) do
    __MODULE_PREFIX__.Accounts.accept_invitation(invitation.id, actor: user)

    case __MODULE_PREFIX__.Accounts.create_workspace_user(invitation.role, invitation.workspace_id, user.id, actor: user) do
      {:ok, _workspace} -> {:ok, "You have been successfully added to the workspace."}
      {:error, _} -> {:error, "Failed to add you to the workspace."}
    end
  end

  def put_flash_from_result(socket, {:ok, msg}),
    do: put_flash(socket, :info, msg)

  def put_flash_from_result(socket, {:error, msg}),
    do: put_flash(socket, :error, msg)
end
