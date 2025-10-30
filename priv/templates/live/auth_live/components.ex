defmodule __MODULE_PREFIX__Web.AuthLive.Components do
  use __MODULE_PREFIX__Web, :live_view

  def sign_in_footer(assigns) do
    ~H"""
    <.footer_wrapper>
      <div class="flex flex-col sm:flex-row justify-between gap-2 text-sm text-base-content/70">
        <p>
          Don't have an account?
          <.link navigate={~p"/register"} class="link link-primary font-medium">
            Register
          </.link>
        </p>
        <p>
          <.link navigate={~p"/reset"} class="link link-primary font-medium">
            Forgot password?
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
        <.link navigate={~p"/sign-in"} class="link link-primary font-medium">
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
end
