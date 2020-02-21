# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.ActivityExpirationPolicy do
  @moduledoc "Adds expiration to all local Create activities"
  @behaviour Pleroma.Web.ActivityPub.MRF

  @impl true
  def filter(activity) do
    activity =
      if activity["type"] == "Create" && local?(activity) do
        maybe_add_expiration(activity)
      else
        activity
      end

    {:ok, activity}
  end

  @impl true
  def describe, do: {:ok, %{}}

  defp local?(%{"id" => id}) do
    String.starts_with?(id, Pleroma.Web.Endpoint.url())
  end

  defp maybe_add_expiration(activity) do
    days = Pleroma.Config.get([:mrf_activity_expiration, :days], 365)
    expires_at = NaiveDateTime.utc_now() |> Timex.shift(days: days)

    with %{"expires_at" => existing_expires_at} <- activity,
         :lt <- NaiveDateTime.compare(existing_expires_at, expires_at) do
      activity
    else
      _ -> Map.put(activity, "expires_at", expires_at)
    end
  end
end
