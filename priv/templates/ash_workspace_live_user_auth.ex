defmodule __MODULE_PREFIX__Web.AshWorkspaceLiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  import Phoenix.Component
  use __MODULE_PREFIX__Web, :verified_routes

  # This is used for nested liveviews to fetch the current user.
  # To use, place the following at the top of that liveview:
  # on_mount {__MODULE_PREFIX__Web.AshWorkspaceLiveUserAuth, :current_user}
  def on_mount(:current_user, _params, session, socket) do
    {:cont, AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)}
  end

  def on_mount(:live_user_optional, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:admin_only, _params, _session, socket) do
    if socket.assigns[:current_user] do
      if socket.assigns[:current_user].role in [:admin, :owner] do
        {:cont, socket}
      else
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
      end

      # If user isn't logged in, redirect to sign in page
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:admin_or_owner, _params, _session, socket) do
    if socket.assigns[:current_user] do
      if socket.assigns[:current_user].role in [:admin, :owner] do
        {:cont, socket}
      else
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
      end

      # If user isn't logged in, redirect to sign in page
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end
end
