defmodule Pleroma.Repo.Migrations.RemoveBackgroundJobs do
  use Ecto.Migration

  import Ecto.Query, only: [from: 2]

  def up do
    from(j in "oban_jobs",
      where:
        j.queue == ^"background" and
          fragment("?->>'op'", j.args) in ^[
            "fetch_data_for_activity",
            "media_proxy_prefetch",
            "media_proxy_preload"
          ] and
          j.worker == ^"Pleroma.Workers.BackgroundWorker",
      select: [:id]
    )
    |> Pleroma.Repo.delete_all()
  end

  def down, do: :ok
end
