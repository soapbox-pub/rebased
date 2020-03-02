# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
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

    ["public", "unlisted", "private", "direct"]
    |> Enum.each(fn visibility ->
      count = status_visibility_count_query(visibility)
      name = "status_visibility_#{visibility}"
      CounterCache.set(name, count)
      Mix.Pleroma.shell_info("Set #{name} to #{count}")
    end)

    Mix.Pleroma.shell_info("Done")
  end

  defp status_visibility_count_query(visibility) do
    Activity
    |> where(
      [a],
      fragment(
        "activity_visibility(?, ?, ?) = ?",
        a.actor,
        a.recipients,
        a.data,
        ^visibility
      )
    )
    |> where([a], fragment("(? ->> 'type'::text) = 'Create'", a.data))
    |> Repo.aggregate(:count, :id, timeout: :timer.minutes(30))
  end
end
