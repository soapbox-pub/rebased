# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.UpdateMarkers do
  use Ecto.Migration
  import Ecto.Query
  alias Pleroma.Repo

  def up do
    update_markers()
  end

  def down do
    :ok
  end

  defp update_markers do
    now = NaiveDateTime.utc_now()

    markers_attrs =
      from(q in "notifications",
        select: %{
          timeline: "notifications",
          user_id: q.user_id,
          last_read_id:
            type(fragment("MAX( CASE WHEN seen = true THEN id ELSE null END )"), :string)
        },
        group_by: [q.user_id]
      )
      |> Repo.all()
      |> Enum.map(fn %{last_read_id: last_read_id} = attrs ->
        attrs
        |> Map.put(:last_read_id, last_read_id || "")
        |> Map.put_new(:inserted_at, now)
        |> Map.put_new(:updated_at, now)
      end)

    markers_attrs
    |> Enum.chunk_every(1000)
    |> Enum.each(fn markers_attrs_chunked ->
      Repo.insert_all("markers", markers_attrs_chunked,
        on_conflict: {:replace, [:last_read_id]},
        conflict_target: [:user_id, :timeline]
      )
    end)
  end
end
