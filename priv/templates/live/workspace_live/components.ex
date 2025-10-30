defmodule __MODULE_PREFIX__Web.WorkspaceLive.Components do
  @moduledoc """
  Components for the workspace list page.
  """
  use __MODULE_PREFIX__Web, :live_component

  # Import AshWorkspace-specific components (card, badge, avatar, modals, etc.)
  import __MODULE_PREFIX__Web.AshWorkspace.CoreComponents

  def page_header(assigns) do
    ~H"""
    <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h1 class="text-3xl font-bold tracking-tight">My Workspaces</h1>
        <p class="mt-2 text-base-content/70">
          Select a workspace to view details or manage team members
        </p>
      </div>
    </div>
    """
  end

  def workspaces_grid(assigns) do
    ~H"""
    <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
      <.workspace_card :for={workspace <- @workspaces} workspace={workspace} />
    </div>
    """
  end

  def workspace_card(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl hover:shadow-2xl transition-shadow">
      <div class="card-body">
        <h2 class="card-title text-xl">
          {@workspace.name}
        </h2>

        <div class="flex items-center gap-2 mt-2">
          <.badge size="sm">
            {human_role(@workspace.role)}
          </.badge>
        </div>

        <div class="card-actions justify-end mt-4">
          <.link
            :if={@workspace.is_admin?}
            navigate={~p"/workspaces/#{@workspace.id}/team"}
            class="btn btn-primary btn-sm"
          >
            Manage Team
          </.link>
          <button :if={!@workspace.is_admin?} class="btn btn-sm btn-disabled" disabled>
            View Only
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp human_role(:admin), do: "Admin"
  defp human_role(:member), do: "Member"
  defp human_role(:billing), do: "Billing"
  defp human_role(_), do: "Member"
end
