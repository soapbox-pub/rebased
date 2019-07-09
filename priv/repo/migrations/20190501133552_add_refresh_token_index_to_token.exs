defmodule Pleroma.Repo.Migrations.AddRefreshTokenIndexToToken do
  use Ecto.Migration

  def change do
    create_if_not_exists(unique_index(:oauth_tokens, [:refresh_token]))
  end
end
