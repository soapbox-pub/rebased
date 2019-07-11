defmodule Pleroma.Repo.Migrations.FixUserTrigramIndex do
  use Ecto.Migration

  def up do
    drop_if_exists(index(:users, [], name: :users_trigram_index))

    create_if_not_exists(
      index(:users, ["(trim(nickname || ' ' || coalesce(name, ''))) gist_trgm_ops"],
        name: :users_trigram_index,
        using: :gist
      )
    )
  end

  def down do
    drop_if_exists(index(:users, [], name: :users_trigram_index))

    create_if_not_exists(
      index(:users, ["(nickname || name) gist_trgm_ops"], name: :users_trigram_index, using: :gist)
    )
  end
end
