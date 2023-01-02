# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

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
