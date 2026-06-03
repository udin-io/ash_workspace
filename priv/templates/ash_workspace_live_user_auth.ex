defmodule __MODULE_PREFIX__Web.AshWorkspaceLiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  import Phoenix.Component
  use __MODULE_PREFIX__Web, :verified_routes
  require Ash.Query

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
    current_user = socket.assigns[:current_user]

    cond do
      is_nil(current_user) ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}

      current_user.role == :admin ->
        {:cont, socket}

      true ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    end
  end

  def on_mount(:workspace_admin, params, _session, socket) do
    current_user = socket.assigns[:current_user]
    workspace_id = Map.get(params, "workspace_id")

    cond do
      is_nil(current_user) ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}

      is_nil(workspace_id) ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}

      true ->
        current_user_id = current_user.id

        __MODULE_PREFIX__.Accounts.WorkspaceUser
        |> Ash.Query.filter(workspace_id == ^workspace_id and user_id == ^current_user_id)
        |> Ash.read_one(actor: current_user)
        |> case do
          {:ok, %{role: :admin}} -> {:cont, socket}
          _ -> {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
        end
    end
  end
end
