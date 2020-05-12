# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Preload.Providers.Timelines do
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.Preload.Providers.Provider

  @behaviour Provider
  @public_url :"/api/v1/timelines/public"

  @impl Provider
  def generate_terms(_params) do
    build_public_tag(%{})
  end

  def build_public_tag(acc) do
    if Pleroma.Config.get([:restrict_unauthenticated, :timelines, :federated], true) do
      acc
    else
      Map.put(acc, @public_url, public_timeline(nil))
    end
  end

  defp public_timeline(user) do
    activities =
      create_timeline_params(user)
      |> Map.put("local_only", false)
      |> ActivityPub.fetch_public_activities()

    StatusView.render("index.json", activities: activities, for: user, as: :activity)
  end

  defp create_timeline_params(user) do
    %{}
    |> Map.put("type", ["Create", "Announce"])
    |> Map.put("blocking_user", user)
    |> Map.put("muting_user", user)
    |> Map.put("user", user)
  end
end
