# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.Oban do
  require Logger

  def warn do
    oban_config = Pleroma.Config.get(Oban)

    crontab =
      [
        Pleroma.Workers.Cron.StatsWorker,
        Pleroma.Workers.Cron.PurgeExpiredActivitiesWorker,
        Pleroma.Workers.Cron.ClearOauthTokenWorker
      ]
      |> Enum.reduce(oban_config[:crontab], fn removed_worker, acc ->
        with acc when is_list(acc) <- acc,
             setting when is_tuple(setting) <-
               Enum.find(acc, fn {_, worker} -> worker == removed_worker end) do
          """
          !!!OBAN CONFIG WARNING!!!
          You are using old workers in Oban crontab settings, which were removed.
          Please, remove setting from crontab in your config file (prod.secret.exs): #{inspect(setting)}
          """
          |> Logger.warn()

          List.delete(acc, setting)
        else
          _ -> acc
        end
      end)

    Pleroma.Config.put(Oban, Keyword.put(oban_config, :crontab, crontab))
  end
end
