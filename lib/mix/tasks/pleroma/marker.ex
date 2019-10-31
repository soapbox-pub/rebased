defmodule Mix.Tasks.Pleroma.Marker do
  use Mix.Task
  import Mix.Pleroma
  import Ecto.Query

  alias Pleroma.Notification
  alias Pleroma.Repo

  def run(["update_markers"]) do
    start_pleroma()

    from(q in Notification,
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
    |> Enum.each(fn attrs ->
      Pleroma.Marker
      |> struct(attrs)
      |> Ecto.Changeset.change()
      |> Pleroma.Repo.insert(
        returning: true,
        on_conflict: {:replace, [:last_read_id, :unread_count]},
        conflict_target: [:user_id, :timeline]
      )
    end)

    shell_info("Done")
  end
end
