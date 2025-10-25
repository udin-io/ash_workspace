defmodule AshWorkspace.Validators.EmailUniquenessInWorkspace do
  @moduledoc """
  Validates that no existing user or pending invitation uses the email in the workspace.

  This validator ensures that when creating an invitation, the email address
  is not already associated with:
  1. An existing user in the workspace
  2. A pending invitation

  ## Usage

      validate AshWorkspace.Validators.EmailUniquenessInWorkspace

  ## Required Configuration

  Your application must configure the domain module and resources:

      config :ash_workspace,
        domain: MyApp.Accounts,
        workspace_user_resource: MyApp.Accounts.WorkspaceUser,
        invitation_resource: MyApp.Accounts.Invitation

  ## Required Code Interfaces

  The WorkspaceUser resource must define:

      code_interface do
        define :get_workspace_users_by_workspace_id,
          action: :get_workspace_users_by_workspace_id,
          args: [:workspace_id]
      end

  The Invitation resource must define:

      code_interface do
        define :get_pending_invitations_by_email,
          action: :get_pending_by_email,
          args: [:email]
      end
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _ctx) do
    email = Ash.Changeset.get_attribute(changeset, :email)
    workspace_id = Ash.Changeset.get_attribute(changeset, :workspace_id)

    cond do
      is_nil(email) or is_nil(workspace_id) ->
        :ok

      email_exists_in_workspace?(email, workspace_id) ->
        {:error,
         [
           %Ash.Error.Changes.InvalidAttribute{
             field: :email,
             message: "A user with this email already exists in the workspace."
           }
         ]}

      pending_invitation_exists?(email) ->
        {:error,
         [
           %Ash.Error.Changes.InvalidAttribute{
             field: :email,
             message: "An invitation with this email already exists and is pending"
           }
         ]}

      true ->
        :ok
    end
  end

  defp email_exists_in_workspace?(email, workspace_id) do
    domain = get_config!(:domain)
    workspace_user_resource = get_config!(:workspace_user_resource)

    case domain.get_workspace_users_by_workspace_id(workspace_id,
           actor: nil,
           tenant: nil,
           authorize?: false,
           load: [:user]
         ) do
      {:ok, workspace_users} ->
        workspace_users
        |> Enum.any?(fn workspace_user ->
          workspace_user.user && to_string(workspace_user.user.email) == to_string(email)
        end)

      _ ->
        false
    end
  end

  defp pending_invitation_exists?(email) do
    domain = get_config!(:domain)

    case domain.get_pending_invitations_by_email(email,
           actor: nil,
           tenant: nil,
           authorize?: false
         ) do
      {:ok, _inv} -> true
      _ -> false
    end
  end

  defp get_config!(key) do
    Application.get_env(:ash_workspace, key) ||
      raise """
      AshWorkspace configuration missing for #{inspect(key)}.

      Please add to your config:

          config :ash_workspace,
            domain: MyApp.Accounts,
            workspace_user_resource: MyApp.Accounts.WorkspaceUser,
            invitation_resource: MyApp.Accounts.Invitation
      """
  end
end
