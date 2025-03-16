# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.FollowBotPolicy do
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy
  alias Pleroma.Config
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  require Logger

  @impl true
  def filter(activity) do
    with follower_nickname <- Config.get([:mrf_follow_bot, :follower_nickname]),
         %User{actor_type: "Service"} = follower <-
           User.get_cached_by_nickname(follower_nickname),
         %{"type" => "Create", "object" => %{"type" => "Note"}} <- activity do
      try_follow(follower, activity)
    else
      nil ->
        Logger.warning(
          "#{__MODULE__} skipped because of missing `:mrf_follow_bot, :follower_nickname` configuration, the :follower_nickname
            account does not exist, or the account is not correctly configured as a bot."
        )

        {:ok, activity}

      _ ->
        {:ok, activity}
    end
  end

  defp try_follow(follower, activity) do
    to = Map.get(activity, "to", [])
    cc = Map.get(activity, "cc", [])
    actor = [activity["actor"]]

    Enum.concat([to, cc, actor])
    |> List.flatten()
    |> Enum.uniq()
    |> User.get_all_by_ap_id()
    |> Enum.each(fn user ->
      with false <- user.local,
           false <- User.following?(follower, user),
           false <- User.locked?(user),
           false <- (user.bio || "") |> String.downcase() |> String.contains?("nobot") do
        Logger.debug(
          "#{__MODULE__}: Follow request from #{follower.nickname} to #{user.nickname}"
        )

        CommonAPI.follow(user, follower)
      end
    end)

    {:ok, activity}
  end

  @impl true
  def describe do
    {:ok, %{}}
  end
end
