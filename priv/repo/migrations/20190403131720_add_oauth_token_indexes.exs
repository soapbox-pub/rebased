defmodule Pleroma.Repo.Migrations.AddOauthTokenIndexes do
  use Ecto.Migration

  def change do
    create_if_not_exists(unique_index(:oauth_tokens, [:token]))
    create_if_not_exists(index(:oauth_tokens, [:app_id]))
    create_if_not_exists(index(:oauth_tokens, [:user_id]))
  end
end
