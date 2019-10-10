defmodule Pleroma.Repo.Migrations.CreateUserTrigramIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists(
      index(:users, ["(nickname || name) gist_trgm_ops"], name: :users_trigram_index, using: :gist)
    )
  end
end
