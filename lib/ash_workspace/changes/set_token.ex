defmodule AshWorkspace.Changes.SetToken do
  @moduledoc """
  Generates and sets a secure random token for invitations.

  This change generates a 32-byte random token, hashes it with Bcrypt,
  and stores the hash in the :token attribute. The raw token is stored
  in the changeset context so it can be used in emails.

  ## Usage

      change AshWorkspace.Changes.SetToken

  The raw token will be available in the changeset context as `:raw_token`
  for use in after_action hooks or notifications.
  """

  use Ash.Resource.Change

  @doc false
  def change(changeset, _opts, _ctx) do
    {raw_token, hashed_token} = generate_token_and_hash()

    changeset
    |> Ash.Changeset.set_context(%{raw_token: raw_token})
    |> Ash.Changeset.force_change_attribute(:token, hashed_token)
  end

  @doc """
  Generates a secure random token and its Bcrypt hash.

  Returns a tuple of `{raw_token, hashed_token}` where:
  - `raw_token` is the URL-safe base64 encoded random bytes
  - `hashed_token` is the Bcrypt hash of the raw token

  ## Examples

      iex> {raw, hashed} = AshWorkspace.Changes.SetToken.generate_token_and_hash()
      iex> is_binary(raw) and is_binary(hashed)
      true
  """
  def generate_token_and_hash do
    raw_token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    hashed_token = Bcrypt.hash_pwd_salt(raw_token)
    {raw_token, hashed_token}
  end
end
