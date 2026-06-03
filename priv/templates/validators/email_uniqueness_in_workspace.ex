defmodule __MODULE_PREFIX__.Accounts.Validators.EmailUniquenessInWorkspace do
  @moduledoc "Validates that no existing user or pending invitation uses the email"

  use Ash.Resource.Validation
  require Ash.Query

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
    __MODULE_PREFIX__.Accounts.User
    |> Ash.Query.filter(email == ^email)
    |> Ash.Query.filter(exists(workspace_users, workspace_id == ^workspace_id))
    |> Ash.read_one(actor: actor)
    |> case do
      {:ok, nil} -> false
      {:ok, _user} -> true
      _ -> false
    end
  end

  defp pending_invitation_exists?(email) do
    case __MODULE_PREFIX__.Accounts.get_pending_invitations_by_email(email) do
      {:ok, _inv} -> true
      _ -> false
    end
  end
end
