defmodule __MODULE_PREFIX__.Accounts.Changes.MakeOwnerRole do
  @moduledoc """
  A custom change to set the user's role to :owner when they register.
  This gives them admin privileges in the application.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.change_attribute(changeset, :role, :owner)
  end

  @impl true
  def atomic(_changeset, _opts, _context) do
    {:atomic, %{role: :owner}}
  end
end
