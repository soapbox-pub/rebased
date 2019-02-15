# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.HellthreadPolicy do
  alias Pleroma.User
  @behaviour Pleroma.Web.ActivityPub.MRF

  defp delist_message(message) do
    delist_threshold = Pleroma.Config.get([:mrf_hellthread, :delist_threshold])
    follower_collection = User.get_cached_by_ap_id(message["actor"]).follower_address

    message =
      with {:public, recipients} <- get_recipient_count(message) do
        if recipients > delist_threshold and delist_threshold > 0 do
          message
          |> Map.put("to", [follower_collection])
          |> Map.put("cc", ["https://www.w3.org/ns/activitystreams#Public"])
        else
          message
        end
      else
        _ -> message
      end

    {:ok, message}
  end

  defp reject_message(message) do
    reject_threshold =
      Pleroma.Config.get(
        [:mrf_hellthread, :reject_threshold],
        Pleroma.Config.get([:mrf_hellthread, :threshold])
      )

    with {_, recipients} <- get_recipient_count(message) do
      if recipients > reject_threshold and reject_threshold > 0 do
        {:reject, nil}
      else
        {:ok, message}
      end
    end
  end

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
    with {:ok, message} <- reject_message(message),
         {:ok, message} <- delist_message(message) do
      {:ok, message}
    else
      _e -> {:reject, nil}
    end
  end

  @impl true
  def filter(message), do: {:ok, message}
end
