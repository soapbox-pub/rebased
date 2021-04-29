# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Preload.Providers.Timelines do
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.Preload.Providers.Provider

  @behaviour Provider
  @public_url "/api/v1/timelines/public"

  @impl Provider
  def generate_terms(params) do
    build_public_tag(%{}, params)
  end

  def build_public_tag(acc, params) do
    if Pleroma.Config.restrict_unauthenticated_access?(:timelines, :federated) do
      acc
    else
      Map.put(acc, @public_url, public_timeline(params))
    end
  end

  defp public_timeline(%{"path" => ["main", "all"]}), do: get_public_timeline(false)

  defp public_timeline(_params), do: get_public_timeline(true)

  defp get_public_timeline(local_only) do
    activities =
      ActivityPub.fetch_public_activities(%{
        type: ["Create"],
        local_only: local_only
      })

    StatusView.render("index.json", activities: activities, for: nil, as: :activity)
  end
end
