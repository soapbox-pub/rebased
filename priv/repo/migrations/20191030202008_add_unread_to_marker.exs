defmodule Pleroma.Repo.Migrations.AddUnreadToMarker do
  use Ecto.Migration
  import Ecto.Query
  alias Pleroma.Repo

  def up do
    alter table(:markers) do
      add_if_not_exists(:unread_count, :integer, default: 0)
    end

    flush()

    update_markers()
  end

  def down do
    alter table(:markers) do
      remove_if_exists(:unread_count, :integer)
    end
  end

  def update_markers do
    now = NaiveDateTime.utc_now()

    markers_attrs =
      from(q in "notifications",
        select: %{
          timeline: "notifications",
          user_id: q.user_id,
          unread_count: fragment("SUM( CASE WHEN seen = false THEN 1 ELSE 0 END )"),
          last_read_id:
            type(fragment("MAX( CASE WHEN seen = true THEN id ELSE null END )"), :string)
        },
        group_by: [q.user_id]
      )
      |> Repo.all()
      |> Enum.map(fn attrs ->
        attrs
        |> Map.put_new(:inserted_at, now)
        |> Map.put_new(:updated_at, now)
      end)

    Repo.insert_all("markers", markers_attrs,
      on_conflict: {:replace, [:last_read_id, :unread_count]},
      conflict_target: [:user_id, :timeline]
    )
  end
end
