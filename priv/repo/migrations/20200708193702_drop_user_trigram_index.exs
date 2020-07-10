defmodule Pleroma.Repo.Migrations.DropUserTrigramIndex do
  @moduledoc "Drops unused trigram index on `users` (FTS index is being used instead)"

  use Ecto.Migration

  def up do
    drop_if_exists(index(:users, [], name: :users_trigram_index))
  end

  def down do
    create_if_not_exists(
      index(:users, ["(trim(nickname || ' ' || coalesce(name, ''))) gist_trgm_ops"],
        name: :users_trigram_index,
        using: :gist
      )
    )
  end
end
