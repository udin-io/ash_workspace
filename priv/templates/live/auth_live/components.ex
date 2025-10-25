defmodule __MODULE_PREFIX__Web.AuthLive.Components do
  use __MODULE_PREFIX__Web, :live_view

  def sign_in_footer(assigns) do
    ~H"""
    <.footer_wrapper>
      <div class="flex justify-between text-sm text-gray-600">
        <p>
          Don't have an account?
          <.link navigate={~p"/register"} class="text-black font-medium hover:underline">
            Register
          </.link>
        </p>
        <p>
          <.link navigate={~p"/reset"} class="text-black font-medium hover:underline">
            Forgot your password?
          </.link>
        </p>
      </div>
    </.footer_wrapper>
    """
  end

  def register_footer(assigns) do
    ~H"""
    <.footer_wrapper>
      <p class="text-sm text-gray-600">
        Already have an account?
        <.link navigate={~p"/sign-in"} class="text-black font-medium hover:underline">
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
end
