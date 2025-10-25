defmodule AshWorkspace.Validators.StrongPasswordValidation do
  @moduledoc """
  Validates that a password meets strong password requirements.

  A strong password must:
  - Be at least 8 characters long
  - Contain at least one uppercase letter (A-Z)
  - Contain at least one lowercase letter (a-z)
  - Contain at least one digit (0-9)
  - Contain at least one special character (non-alphanumeric)

  ## Usage

  In your User resource's registration or password change actions:

      create :register_with_password do
        argument :password, :string, sensitive?: true

        validate AshWorkspace.Validators.StrongPasswordValidation
      end

  ## Configuration

  You can optionally configure custom requirements:

      config :ash_workspace, :password_requirements,
        min_length: 10,
        require_uppercase: true,
        require_lowercase: true,
        require_digit: true,
        require_special: true

  ## Examples

      # Using defaults
      validate AshWorkspace.Validators.StrongPasswordValidation

      # Will validate that password has uppercase, lowercase, digit, and special character
  """

  use Ash.Resource.Validation

  @default_min_length 8

  @impl true
  def validate(changeset, _opts, _context) do
    password = Ash.Changeset.get_argument(changeset, :password) || ""

    if valid_strong_password?(password) do
      :ok
    else
      {:error,
       Ash.Error.Changes.InvalidArgument.exception(
         field: :password,
         message: password_requirements_message()
       )}
    end
  end

  defp valid_strong_password?(password) when is_binary(password) do
    requirements = get_password_requirements()

    String.length(password) >= requirements.min_length &&
      (!requirements.require_uppercase || String.match?(password, ~r/[A-Z]/)) &&
      (!requirements.require_lowercase || String.match?(password, ~r/[a-z]/)) &&
      (!requirements.require_digit || String.match?(password, ~r/\d/)) &&
      (!requirements.require_special || String.match?(password, ~r/[^A-Za-z0-9]/))
  end

  defp valid_strong_password?(_), do: false

  defp get_password_requirements do
    defaults = %{
      min_length: @default_min_length,
      require_uppercase: true,
      require_lowercase: true,
      require_digit: true,
      require_special: true
    }

    configured = Application.get_env(:ash_workspace, :password_requirements, %{})

    Map.merge(defaults, Map.new(configured))
  end

  defp password_requirements_message do
    requirements = get_password_requirements()
    parts = ["Password must be at least #{requirements.min_length} characters"]

    parts =
      if requirements.require_uppercase or requirements.require_lowercase or
           requirements.require_digit or requirements.require_special do
        required =
          [
            requirements.require_uppercase && "uppercase letter",
            requirements.require_lowercase && "lowercase letter",
            requirements.require_digit && "digit",
            requirements.require_special && "special character"
          ]
          |> Enum.reject(&(&1 == false))
          |> Enum.join(", ")

        parts ++ ["and include: #{required}"]
      else
        parts
      end

    Enum.join(parts, " ")
  end
end
