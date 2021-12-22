# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.ActivityExpirationPolicy do
  @moduledoc "Adds expiration to all local Create activities"
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  @impl true
  def filter(activity) do
    activity =
      if note?(activity) and local?(activity) do
        maybe_add_expiration(activity)
      else
        activity
      end

    {:ok, activity}
  end

  @impl true
  def describe, do: {:ok, %{}}

  defp local?(%{"actor" => actor}) do
    String.starts_with?(actor, Pleroma.Web.Endpoint.url())
  end

  defp note?(activity) do
    match?(%{"type" => "Create", "object" => %{"type" => "Note"}}, activity)
  end

  defp maybe_add_expiration(activity) do
    days = Pleroma.Config.get([:mrf_activity_expiration, :days], 365)
    expires_at = DateTime.utc_now() |> Timex.shift(days: days)

    with %{"expires_at" => existing_expires_at} <- activity,
         :lt <- DateTime.compare(existing_expires_at, expires_at) do
      activity
    else
      _ -> Map.put(activity, "expires_at", expires_at)
    end
  end

  @impl true
  def config_description do
    %{
      key: :mrf_activity_expiration,
      related_policy: "Pleroma.Web.ActivityPub.MRF.ActivityExpirationPolicy",
      label: "MRF Activity Expiration Policy",
      description: "Adds automatic expiration to all local activities",
      children: [
        %{
          key: :days,
          type: :integer,
          description: "Default global expiration time for all local activities (in days)",
          suggestions: [90, 365]
        }
      ]
    }
  end
end
