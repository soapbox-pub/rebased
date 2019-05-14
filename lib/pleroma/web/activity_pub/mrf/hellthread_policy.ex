# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.HellthreadPolicy do
  alias Pleroma.User
  @moduledoc "Block messages with too much mentions (configurable)"

  @behaviour Pleroma.Web.ActivityPub.MRF

  defp delist_message(message, threshold) when threshold > 0 do
    follower_collection = User.get_cached_by_ap_id(message["actor"]).follower_address

    follower_collection? = Enum.member?(message["to"] ++ message["cc"], follower_collection)

    message =
      case get_recipient_count(message) do
        {:public, recipients}
        when follower_collection? and recipients > threshold ->
          message
          |> Map.put("to", [follower_collection])
          |> Map.put("cc", ["https://www.w3.org/ns/activitystreams#Public"])

        {:public, recipients} when recipients > threshold ->
          message
          |> Map.put("to", [])
          |> Map.put("cc", ["https://www.w3.org/ns/activitystreams#Public"])

        _ ->
          message
      end

    {:ok, message}
  end

  defp delist_message(message, _threshold), do: {:ok, message}

  defp reject_message(message, threshold) when threshold > 0 do
    with {_, recipients} <- get_recipient_count(message) do
      if recipients > threshold do
        {:reject, nil}
      else
        {:ok, message}
      end
    end
  end

  defp reject_message(message, _threshold), do: {:ok, message}

  defp get_recipient_count(message) do
    recipients = (message["to"] || []) ++ (message["cc"] || [])
    follower_collection = User.get_cached_by_ap_id(message["actor"]).follower_address

    if Enum.member?(recipients, "https://www.w3.org/ns/activitystreams#Public") do
      recipients =
        recipients
        |> List.delete("https://www.w3.org/ns/activitystreams#Public")
        |> List.delete(follower_collection)

      {:public, length(recipients)}
    else
      recipients =
        recipients
        |> List.delete(follower_collection)

      {:not_public, length(recipients)}
    end
  end

  @impl true
  def filter(%{"type" => "Create"} = message) do
    reject_threshold =
      Pleroma.Config.get(
        [:mrf_hellthread, :reject_threshold],
        Pleroma.Config.get([:mrf_hellthread, :threshold])
      )

    delist_threshold = Pleroma.Config.get([:mrf_hellthread, :delist_threshold])

    with {:ok, message} <- reject_message(message, reject_threshold),
         {:ok, message} <- delist_message(message, delist_threshold) do
      {:ok, message}
    else
      _e -> {:reject, nil}
    end
  end

  @impl true
  def filter(message), do: {:ok, message}
end
