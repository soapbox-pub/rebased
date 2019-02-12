# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.HellthreadPolicy do
  alias Pleroma.User
  @behaviour Pleroma.Web.ActivityPub.MRF

  defp delist_message(message) do
    follower_collection = User.get_cached_by_ap_id(message["actor"]).follower_address

    message
    |> Map.put("to", [follower_collection])
    |> Map.put("cc", ["https://www.w3.org/ns/activitystreams#Public"])
  end

  defp get_recipient_count(message) do
    recipients = (message["to"] || []) ++ (message["cc"] || [])

    cond do
      Enum.member?(recipients, "https://www.w3.org/ns/activitystreams#Public") &&
          Enum.find(recipients, &String.ends_with?(&1, "/followers")) ->
        length(recipients) - 2

      Enum.member?(recipients, "https://www.w3.org/ns/activitystreams#Public") ||
          Enum.find(recipients, &String.ends_with?(&1, "/followers")) ->
        length(recipients) - 1

      true ->
        length(recipients)
    end
  end

  @impl true
  def filter(%{"type" => "Create"} = message) do
    delist_threshold = Pleroma.Config.get([:mrf_hellthread, :delist_threshold])

    reject_threshold =
      Pleroma.Config.get(
        [:mrf_hellthread, :reject_threshold],
        Pleroma.Config.get([:mrf_hellthread, :threshold])
      )

    recipients = get_recipient_count(message)

    cond do
      recipients > reject_threshold and reject_threshold > 0 ->
        {:reject, nil}

      recipients > delist_threshold and delist_threshold > 0 ->
        if Enum.member?(message["to"], "https://www.w3.org/ns/activitystreams#Public") or
             Enum.member?(message["cc"], "https://www.w3.org/ns/activitystreams#Public") do
          {:ok, delist_message(message)}
        else
          {:ok, message}
        end

      true ->
        {:ok, message}
    end
  end

  @impl true
  def filter(message), do: {:ok, message}
end
