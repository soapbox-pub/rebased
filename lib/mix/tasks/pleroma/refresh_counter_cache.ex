# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.RefreshCounterCache do
  @shortdoc "Refreshes counter cache"

  use Mix.Task

  alias Pleroma.Activity
  alias Pleroma.CounterCache
  alias Pleroma.Repo

  require Logger
  import Ecto.Query

  def run([]) do
    Mix.Pleroma.start_pleroma()

    instances =
      Activity
      |> distinct([a], true)
      |> select([a], fragment("split_part(?, '/', 3)", a.actor))
      |> Repo.all()

    instances
    |> Enum.with_index(1)
    |> Enum.each(fn {instance, i} ->
      counters = instance_counters(instance)
      CounterCache.set(instance, counters)

      Mix.Pleroma.shell_info(
        "[#{i}/#{length(instances)}] Setting #{instance} counters: #{inspect(counters)}"
      )
    end)

    Mix.Pleroma.shell_info("Done")
  end

  defp instance_counters(instance) do
    counters = %{"public" => 0, "unlisted" => 0, "private" => 0, "direct" => 0}

    Activity
    |> where([a], fragment("(? ->> 'type'::text) = 'Create'", a.data))
    |> where([a], fragment("split_part(?, '/', 3) = ?", a.actor, ^instance))
    |> select(
      [a],
      {fragment(
         "activity_visibility(?, ?, ?)",
         a.actor,
         a.recipients,
         a.data
       ), count(a.id)}
    )
    |> group_by(
      [a],
      fragment(
        "activity_visibility(?, ?, ?)",
        a.actor,
        a.recipients,
        a.data
      )
    )
    |> Repo.all(timeout: :timer.minutes(30))
    |> Enum.reduce(counters, fn {visibility, count}, acc ->
      Map.put(acc, visibility, count)
    end)
  end
end
