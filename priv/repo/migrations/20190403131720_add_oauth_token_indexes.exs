defmodule Pleroma.Repo.Migrations.AddOauthTokenIndexes do
  use Ecto.Migration

  def change do
    create(unique_index(:oauth_tokens, [:token]))
    create(index(:oauth_tokens, [:app_id]))
    create(index(:oauth_tokens, [:user_id]))
  end
end
