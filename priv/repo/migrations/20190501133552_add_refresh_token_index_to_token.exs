defmodule Pleroma.Repo.Migrations.AddRefreshTokenIndexToToken do
  use Ecto.Migration

  def change do
    create(unique_index(:oauth_tokens, [:refresh_token]))
  end
end
