defmodule __MODULE_PREFIX__.Accounts.Validators.StrongPasswordValidation do
  @moduledoc """
  Validates that a password is strong (uppercase, lowercase, digit, special character).
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    password = Ash.Changeset.get_argument(changeset, :password) || ""

    if valid_strong_password?(password) do
      :ok
    else
      {:error,
       Ash.Error.Changes.InvalidArgument.exception(
         field: :password,
         message: "Password must include uppercase, lowercase, digit, and special character"
       )}
    end
  end

  defp valid_strong_password?(password) when is_binary(password) do
    String.length(password) >= 8 &&
      String.match?(password, ~r/[A-Z]/) &&
      String.match?(password, ~r/[a-z]/) &&
      String.match?(password, ~r/\d/) &&
      String.match?(password, ~r/[^A-Za-z0-9]/)
  end

  defp valid_strong_password?(_), do: false
end
