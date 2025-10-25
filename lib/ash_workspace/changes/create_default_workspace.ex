defmodule AshWorkspace.Changes.CreateDefaultWorkspace do
  @moduledoc """
  Creates a default workspace for a new user during registration.

  This change is designed to be used on user registration actions.
  It checks for a `:workspace_name` argument and, if present, creates
  a new workspace and associates the user with it as an admin.

  ## Usage

  In your User resource's register action:

      create :register_with_password do
        argument :workspace_name, :string, allow_nil?: true

        change AshWorkspace.Changes.CreateDefaultWorkspace
      end

  ## Options

  This change accepts the following options:

  - `:relationship_name` - The name of the many_to_many relationship to workspaces.
    Defaults to `:workspaces`.
  - `:role` - The role to assign the user in the workspace. Defaults to `"admin"`.
  - `:argument_name` - The name of the argument containing the workspace name.
    Defaults to `:workspace_name`.

  ## Examples

      # Using defaults
      change AshWorkspace.Changes.CreateDefaultWorkspace

      # Custom relationship and role
      change {AshWorkspace.Changes.CreateDefaultWorkspace,
              relationship_name: :orgs, role: "owner"}
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, opts, _context) do
    relationship_name = opts[:relationship_name] || :workspaces
    role = opts[:role] || "admin"
    argument_name = opts[:argument_name] || :workspace_name

    case Ash.Changeset.get_argument(changeset, argument_name) do
      nil ->
        changeset

      name ->
        Ash.Changeset.manage_relationship(
          changeset,
          relationship_name,
          [%{name: name, role: role}],
          on_no_match: :create
        )
    end
  end

  @impl true
  def atomic(changeset, opts, context) do
    {:ok, change(changeset, opts, context)}
  end
end
