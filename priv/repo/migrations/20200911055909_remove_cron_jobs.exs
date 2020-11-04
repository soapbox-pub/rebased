defmodule Pleroma.Repo.Migrations.RemoveCronJobs do
  use Ecto.Migration

  import Ecto.Query, only: [from: 2]

  def up do
    from(j in "oban_jobs",
      where:
        j.worker in ^[
          "Pleroma.Workers.Cron.PurgeExpiredActivitiesWorker",
          "Pleroma.Workers.Cron.StatsWorker",
          "Pleroma.Workers.Cron.ClearOauthTokenWorker"
        ],
      select: [:id]
    )
    |> Pleroma.Repo.delete_all()
  end

  def down, do: :ok
end
