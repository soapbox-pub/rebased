defmodule Pleroma.Repo.Migrations.RemoveDuplicatesFromActivityExpirationQueue do
  use Ecto.Migration

  import Ecto.Query, only: [from: 2]

  def up do
    duplicate_ids =
      from(j in Oban.Job,
        where: j.queue == "activity_expiration",
        where: j.worker == "Pleroma.Workers.PurgeExpiredActivity",
        where: j.state == "scheduled",
        select:
          {fragment("(?)->>'activity_id'", j.args), fragment("array_agg(?)", j.id), count(j.id)},
        group_by: fragment("(?)->>'activity_id'", j.args),
        having: count(j.id) > 1
      )
      |> Pleroma.Repo.all()
      |> Enum.map(fn {_, ids, _} ->
        max_id = Enum.max(ids)
        List.delete(ids, max_id)
      end)
      |> List.flatten()

    from(j in Oban.Job, where: j.id in ^duplicate_ids)
    |> Pleroma.Repo.delete_all()
  end

  def down, do: :noop
end
