# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Healthcheck do
  @moduledoc """
  Module collects metrics about app and assign healthy status.
  """
  alias Pleroma.Healthcheck
  alias Pleroma.Repo

  @derive Jason.Encoder
  defstruct pool_size: 0,
            active: 0,
            idle: 0,
            memory_used: 0,
            job_queue_stats: nil,
            healthy: true

  @type t :: %__MODULE__{
          pool_size: non_neg_integer(),
          active: non_neg_integer(),
          idle: non_neg_integer(),
          memory_used: number(),
          job_queue_stats: map(),
          healthy: boolean()
        }

  @spec system_info() :: t()
  def system_info do
    %Healthcheck{
      memory_used: Float.round(:erlang.memory(:total) / 1024 / 1024, 2)
    }
    |> assign_db_info()
    |> assign_job_queue_stats()
    |> check_health()
  end

  defp assign_db_info(healthcheck) do
    database = Pleroma.Config.get([Repo, :database])

    query =
      "select state, count(pid) from pg_stat_activity where datname = '#{database}' group by state;"

    result = Repo.query!(query)
    pool_size = Pleroma.Config.get([Repo, :pool_size])

    db_info =
      Enum.reduce(result.rows, %{active: 0, idle: 0}, fn [state, cnt], states ->
        if state == "active" do
          Map.put(states, :active, states.active + cnt)
        else
          Map.put(states, :idle, states.idle + cnt)
        end
      end)
      |> Map.put(:pool_size, pool_size)

    Map.merge(healthcheck, db_info)
  end

  defp assign_job_queue_stats(healthcheck) do
    stats = Pleroma.JobQueueMonitor.stats()
    Map.put(healthcheck, :job_queue_stats, stats)
  end

  @spec check_health(Healthcheck.t()) :: Healthcheck.t()
  def check_health(%{pool_size: pool_size, active: active} = check)
      when active >= pool_size do
    %{check | healthy: false}
  end

  def check_health(check), do: check
end
