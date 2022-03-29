# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RemoveCronStatsWorkerFromObanConfig do
  use Ecto.Migration

  def change do
    with %Pleroma.ConfigDB{} = config <-
           Pleroma.ConfigDB.get_by_params(%{group: :pleroma, key: Oban}),
         crontab when is_list(crontab) <- config.value[:crontab],
         index when is_integer(index) <-
           Enum.find_index(crontab, fn {_, worker} ->
             worker == Pleroma.Workers.Cron.StatsWorker
           end) do
      updated_value = Keyword.put(config.value, :crontab, List.delete_at(crontab, index))

      config
      |> Ecto.Changeset.change(value: updated_value)
      |> Pleroma.Repo.update()
    end
  end
end
