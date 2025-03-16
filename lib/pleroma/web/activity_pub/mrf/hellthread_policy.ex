# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.HellthreadPolicy do
  alias Pleroma.User

  require Pleroma.Constants

  @moduledoc "Block activities with too much mentions (configurable)"

  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  defp delist_activity(activity, threshold) when threshold > 0 do
    follower_collection = User.get_cached_by_ap_id(activity["actor"]).follower_address
    to = activity["to"] || []
    cc = activity["cc"] || []

    follower_collection? = Enum.member?(to ++ cc, follower_collection)

    activity =
      case get_recipient_count(activity) do
        {:public, recipients}
        when follower_collection? and recipients > threshold ->
          activity
          |> Map.put("to", [follower_collection])
          |> Map.put("cc", [Pleroma.Constants.as_public()])

        {:public, recipients} when recipients > threshold ->
          activity
          |> Map.put("to", [])
          |> Map.put("cc", [Pleroma.Constants.as_public()])

        _ ->
          activity
      end

    {:ok, activity}
  end

  defp delist_activity(activity, _threshold), do: {:ok, activity}

  defp reject_activity(activity, threshold) when threshold > 0 do
    with {_, recipients} <- get_recipient_count(activity) do
      if recipients > threshold do
        {:reject, "[HellthreadPolicy] #{recipients} recipients is over the limit of #{threshold}"}
      else
        {:ok, activity}
      end
    end
  end

  defp reject_activity(activity, _threshold), do: {:ok, activity}

  defp get_recipient_count(activity) do
    recipients = (activity["to"] || []) ++ (activity["cc"] || [])
    follower_collection = User.get_cached_by_ap_id(activity["actor"]).follower_address

    if Enum.member?(recipients, Pleroma.Constants.as_public()) do
      recipients =
        recipients
        |> List.delete(Pleroma.Constants.as_public())
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
  def filter(%{"type" => "Create", "object" => %{"type" => object_type}} = activity)
      when object_type in ~w{Note Article} do
    reject_threshold =
      Pleroma.Config.get(
        [:mrf_hellthread, :reject_threshold],
        Pleroma.Config.get([:mrf_hellthread, :threshold])
      )

    delist_threshold = Pleroma.Config.get([:mrf_hellthread, :delist_threshold])

    with {:ok, activity} <- reject_activity(activity, reject_threshold),
         {:ok, activity} <- delist_activity(activity, delist_threshold) do
      {:ok, activity}
    else
      e -> e
    end
  end

  @impl true
  def filter(activity), do: {:ok, activity}

  @impl true
  def describe,
    do: {:ok, %{mrf_hellthread: Pleroma.Config.get(:mrf_hellthread) |> Enum.into(%{})}}

  @impl true
  def config_description do
    %{
      key: :mrf_hellthread,
      related_policy: "Pleroma.Web.ActivityPub.MRF.HellthreadPolicy",
      label: "MRF Hellthread",
      description: "Block activities with excessive user mentions",
      children: [
        %{
          key: :delist_threshold,
          type: :integer,
          description:
            "Number of mentioned users after which the activity gets removed from timelines and" <>
              "disables notifications. Set to 0 to disable.",
          suggestions: [10]
        },
        %{
          key: :reject_threshold,
          type: :integer,
          description:
            "Number of mentioned users after which the activity gets rejected. Set to 0 to disable.",
          suggestions: [20]
        }
      ]
    }
  end
end
