defmodule Pleroma.Repo.Migrations.PublisherJobChange do
  use Ecto.Migration

  alias Pleroma.Activity
  import Ecto.Query

  def up do
    query =
      from(j in Oban.Job,
        where: j.worker == "Pleroma.Workers.PublisherWorker",
        where: j.state in ["available", "retryable"]
      )

    jobs =
      Oban |> Oban.config() |> Oban.Repo.all(query)

    Enum.each(jobs, fn job ->
      args = job.args
      activity = Activity.get_by_ap_id(args["id"])

      updated_args = Map.put(args, "activity_id", activity.id)

      Pleroma.Workers.PublisherWorker.new(updated_args)
      |> Oban.insert()
    end)
  end
end
