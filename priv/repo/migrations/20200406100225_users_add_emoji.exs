# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.UsersPopulateEmoji do
  use Ecto.Migration

  import Ecto.Query

  alias Pleroma.User
  alias Pleroma.Repo

  def up do
    execute("ALTER TABLE users ALTER COLUMN emoji SET DEFAULT '{}'::jsonb")
    execute("UPDATE users SET emoji = DEFAULT WHERE emoji = '[]'::jsonb")

    from(u in User)
    |> select([u], struct(u, [:id, :ap_id, :source_data]))
    |> Repo.stream()
    |> Enum.each(fn user ->
      emoji =
        user.source_data
        |> Map.get("tag", [])
        |> Enum.filter(fn
          %{"type" => "Emoji"} -> true
          _ -> false
        end)
        |> Enum.reduce(%{}, fn %{"icon" => %{"url" => url}, "name" => name}, acc ->
          Map.put(acc, String.trim(name, ":"), url)
        end)

      user
      |> Ecto.Changeset.cast(%{emoji: emoji}, [:emoji])
      |> Repo.update()
    end)
  end

  def down do
    execute("ALTER TABLE users ALTER COLUMN emoji SET DEFAULT '[]'::jsonb")
    execute("UPDATE users SET emoji = DEFAULT WHERE emoji = '{}'::jsonb")
  end
end
