defmodule Pleroma.Repo.Migrations.AddUnreadToMarker do
  use Ecto.Migration
  import Ecto.Query
  alias Pleroma.Repo
  alias Pleroma.Notification

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
    from(q in Notification,
      select: %{
        timeline: "notifications",
        user_id: q.user_id,
        unread_count: fragment("COUNT(*) FILTER (WHERE seen = false) as unread_count"),
        last_read_id: fragment("(MAX(id) FILTER (WHERE seen = true)::text) as last_read_id ")
      },
      group_by: [q.user_id]
    )
    |> Repo.all()
    |> Enum.reduce(Ecto.Multi.new(), fn attrs, multi ->
      marker =
        Pleroma.Marker
        |> struct(attrs)
        |> Ecto.Changeset.change()

      multi
      |> Ecto.Multi.insert(attrs[:user_id], marker,
        returning: true,
        on_conflict: {:replace, [:last_read_id, :unread_count]},
        conflict_target: [:user_id, :timeline]
      )
    end)
    |> Pleroma.Repo.transaction()
  end
end
