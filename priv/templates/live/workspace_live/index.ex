defmodule __MODULE_PREFIX__Web.WorkspaceLive.Index do
  @moduledoc """
  LiveView for displaying all workspaces a user belongs to.
  Shows workspace name, user's role, and allows admins to manage team.
  """

  use __MODULE_PREFIX__Web, :live_view
  alias __MODULE_PREFIX__.Accounts
  import __MODULE_PREFIX__Web.WorkspaceLive.Components

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_page={@current_page}>
      <div class="bg-base-200/50 min-h-screen p-4 sm:p-6 lg:p-8">
        <div class="max-w-4xl mx-auto space-y-8">
          <.page_header />
          <.workspaces_grid workspaces={@workspaces} />
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> setup_page_defaults()}
  end

  defp setup_page_defaults(socket) do
    workspaces = load_user_workspaces(socket.assigns.current_user)

    assign(socket,
      page_title: "My Workspaces",
      current_page: "workspaces",
      workspaces: workspaces
    )
  end

  defp load_user_workspaces(user) do
    # Load user with workspace_users and their workspaces
    user = Ash.load!(user, workspace_users: [:workspace])

    # Transform into a list with workspace info and user's role
    Enum.map(user.workspace_users, fn wu ->
      %{
        id: wu.workspace.id,
        name: wu.workspace.name,
        role: wu.role,
        is_admin?: wu.role == :admin
      }
    end)
    |> Enum.sort_by(& &1.name, :asc)
  end
end
