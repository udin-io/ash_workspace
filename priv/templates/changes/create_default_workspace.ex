defmodule __MODULE_PREFIX__.Accounts.Changes.CreateDefaultWorkspace do
  @moduledoc """
  A custom change to create a default workspace for a new user.
  """
  use Ash.Resource.Change

  # This function is the entry point for the change.
  # It receives the changeset and any options passed from the action.
  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_argument(changeset, :workspace_name) do
      nil ->
        changeset

      name ->
        Ash.Changeset.manage_relationship(
          changeset,
          :workspaces,
          [%{name: name, role: :admin}],
          on_no_match: :create,
          join_keys: [:role]
        )
    end
  end

  @impl true
  def atomic(changeset, opts, context) do
    {:ok, change(changeset, opts, context)}
  end
end
