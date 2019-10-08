defmodule Pleroma.Repo.Migrations.CreateUserFtsIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists(
      index(
        :users,
        [
          """
          (setweight(to_tsvector('simple', regexp_replace(nickname, '\\W', ' ', 'g')), 'A') ||
          setweight(to_tsvector('simple', regexp_replace(coalesce(name, ''), '\\W', ' ', 'g')), 'B'))
          """
        ],
        name: :users_fts_index,
        using: :gin
      )
    )
  end
end
