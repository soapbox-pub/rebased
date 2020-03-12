# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
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

  def run(["render_timeline", nickname | _] = args) do
    start_pleroma()
    user = Pleroma.User.get_by_nickname(nickname)

    activities =
      %{}
      |> Map.put("type", ["Create", "Announce"])
      |> Map.put("blocking_user", user)
      |> Map.put("muting_user", user)
      |> Map.put("user", user)
      |> Map.put("limit", 4096)
      |> Pleroma.Web.ActivityPub.ActivityPub.fetch_public_activities()
      |> Enum.reverse()

    inputs = %{
      "1 activity" => Enum.take_random(activities, 1),
      "10 activities" => Enum.take_random(activities, 10),
      "20 activities" => Enum.take_random(activities, 20),
      "40 activities" => Enum.take_random(activities, 40),
      "80 activities" => Enum.take_random(activities, 80)
    }

    inputs =
      if Enum.at(args, 2) == "extended" do
        Map.merge(inputs, %{
          "200 activities" => Enum.take_random(activities, 200),
          "500 activities" => Enum.take_random(activities, 500),
          "2000 activities" => Enum.take_random(activities, 2000),
          "4096 activities" => Enum.take_random(activities, 4096)
        })
      else
        inputs
      end

    Benchee.run(
      %{
        "Standart rendering" => fn activities ->
          Pleroma.Web.MastodonAPI.StatusView.render("index.json", %{
            activities: activities,
            for: user,
            as: :activity
          })
        end
      },
      inputs: inputs
    )
  end
end
