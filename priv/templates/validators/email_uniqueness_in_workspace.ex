defmodule __MODULE_PREFIX__.Accounts.Validators.EmailUniquenessInWorkspace do
  @moduledoc "Validates that no existing user or pending invitation uses the email"

  use Ash.Resource.Validation

  def validate(changeset, _opts, ctx) do
    email = Ash.Changeset.get_attribute(changeset, :email)
    workspace_id = Ash.Changeset.get_attribute(changeset, :workspace_id)

    cond do
      is_nil(email) or is_nil(workspace_id) ->
        :ok

      email_exists_in_workspace?(email, workspace_id, ctx.actor) ->
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

  defp email_exists_in_workspace?(email, workspace_id, actor) do
    case __MODULE_PREFIX__.Accounts.get_workspace_users_by_workspace_id(workspace_id) do
      {:ok, workspace_users} ->
        Enum.any?(workspace_users, fn workspace_user ->
          case Ash.load(workspace_user, :user, actor: actor) do
            {:ok, %{user: user}} when not is_nil(user) ->
              to_string(user.email) == to_string(email)

            _ ->
              false
          end
        end)

      _ ->
        false
    end
  end

  defp pending_invitation_exists?(email) do
    case __MODULE_PREFIX__.Accounts.get_pending_invitations_by_email(email) do
      {:ok, _inv} -> true
      _ -> false
    end
  end
end
