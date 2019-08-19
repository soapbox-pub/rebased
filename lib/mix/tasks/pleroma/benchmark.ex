# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Benchmark do
  import Mix.Pleroma
  use Mix.Task

  def run(["search"]) do
    start_pleroma()

    Benchee.run(%{
      "search" => fn ->
        Pleroma.Activity.search(nil, "cofe")
      end
    })
  end

  def run(["tag"]) do
    start_pleroma()

    Benchee.run(%{
      "tag" => fn ->
        %{"type" => "Create", "tag" => "cofe"}
        |> Pleroma.Web.ActivityPub.ActivityPub.fetch_public_activities()
      end
    })
  end

  def run(["render_timeline", nickname]) do
    start_pleroma()
    user = Pleroma.User.get_by_nickname(nickname)

    activities =
      %{}
      |> Map.put("type", ["Create", "Announce"])
      |> Map.put("blocking_user", user)
      |> Map.put("muting_user", user)
      |> Map.put("user", user)
      |> Map.put("limit", 80)
      |> Pleroma.Web.ActivityPub.ActivityPub.fetch_public_activities()
      |> Enum.reverse()

    inputs = %{
      "One activity" => Enum.take_random(activities, 1),
      "Ten activities" => Enum.take_random(activities, 10),
      "Twenty activities" => Enum.take_random(activities, 20),
      "Forty activities" => Enum.take_random(activities, 40),
      "Eighty activities" => Enum.take_random(activities, 80)
    }

    Benchee.run(
      %{
        "Parallel rendering" => fn activities ->
          Pleroma.Web.MastodonAPI.StatusView.render("index.json", %{
            activities: activities,
            for: user,
            as: :activity
          })
        end,
        "Standart rendering" => fn activities ->
          Pleroma.Web.MastodonAPI.StatusView.render("index.json", %{
            activities: activities,
            for: user,
            as: :activity,
            parallel: false
          })
        end
      },
      inputs: inputs
    )
  end
end
