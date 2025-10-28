defmodule __MODULE_PREFIX__Web.AshWorkspaceAuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  # configure your UI overrides here

  # First argument to `override` is the component name you are overriding.
  # The body contains any number of configurations you wish to override
  # Below are some examples

  # For a complete reference, see https://hexdocs.pm/ash_authentication_phoenix/ui-overrides.html

  override AshAuthentication.Phoenix.Components.Banner do
    set :image_url, nil
    set :dark_image_url, nil
    set :text, "__APP_NAME__"
    set :text_class, "text-3xl fontweight-bold text-primary"
  end

  # override AshAuthentication.Phoenix.Components.SignIn do
  #  set :show_banner, false
  # end
end
