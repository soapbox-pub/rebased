defmodule Pleroma.Repo.Migrations.CreateMfaTokens do
  use Ecto.Migration

  def change do
    create table(:mfa_tokens) do
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all))
      add(:authorization_id, references(:oauth_authorizations, on_delete: :delete_all))
      add(:token, :string)
      add(:valid_until, :naive_datetime_usec)

      timestamps()
    end

    create(unique_index(:mfa_tokens, :token))
  end
end
