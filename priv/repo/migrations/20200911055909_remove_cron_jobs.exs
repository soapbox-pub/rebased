# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

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
