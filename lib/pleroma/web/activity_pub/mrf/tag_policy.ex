# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.TagPolicy do
  alias Pleroma.User
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy
  @moduledoc """
     Apply policies based on user tags

     This policy applies policies on a user activities depending on their tags
     on your instance.

     - `mrf_tag:media-force-nsfw`: Mark as sensitive on presence of attachments
     - `mrf_tag:media-strip`: Remove attachments
     - `mrf_tag:force-unlisted`: Mark as unlisted (removes from the federated timeline)
     - `mrf_tag:sandbox`: Remove from public (local and federated) timelines
     - `mrf_tag:disable-remote-subscription`: Reject non-local follow requests
     - `mrf_tag:disable-any-subscription`: Reject any follow requests
  """

  require Pleroma.Constants

  defp get_tags(%User{tags: tags}) when is_list(tags), do: tags
  defp get_tags(_), do: []

  defp process_tag(
         "mrf_tag:media-force-nsfw",
         %{
           "type" => type,
           "object" => %{"attachment" => object_attachment}
         } = activity
       )
       when length(object_attachment) > 0 and type in ["Create", "Update"] do
    {:ok, Kernel.put_in(activity, ["object", "sensitive"], true)}
  end

  defp process_tag(
         "mrf_tag:media-strip",
         %{
           "type" => type,
           "object" => %{"attachment" => object_attachment} = object
         } = activity
       )
       when length(object_attachment) > 0 and type in ["Create", "Update"] do
    object = Map.delete(object, "attachment")
    activity = Map.put(activity, "object", object)

    {:ok, activity}
  end

  defp process_tag(
         "mrf_tag:force-unlisted",
         %{
           "type" => "Create",
           "to" => to,
           "cc" => cc,
           "actor" => actor,
           "object" => object
         } = activity
       ) do
    user = User.get_cached_by_ap_id(actor)

    if Enum.member?(to, Pleroma.Constants.as_public()) do
      to = List.delete(to, Pleroma.Constants.as_public()) ++ [user.follower_address]
      cc = List.delete(cc, user.follower_address) ++ [Pleroma.Constants.as_public()]

      object =
        object
        |> Map.put("to", to)
        |> Map.put("cc", cc)

      activity =
        activity
        |> Map.put("to", to)
        |> Map.put("cc", cc)
        |> Map.put("object", object)

      {:ok, activity}
    else
      {:ok, activity}
    end
  end

  defp process_tag(
         "mrf_tag:sandbox",
         %{
           "type" => "Create",
           "to" => to,
           "cc" => cc,
           "actor" => actor,
           "object" => object
         } = activity
       ) do
    user = User.get_cached_by_ap_id(actor)

    if Enum.member?(to, Pleroma.Constants.as_public()) or
         Enum.member?(cc, Pleroma.Constants.as_public()) do
      to = List.delete(to, Pleroma.Constants.as_public()) ++ [user.follower_address]
      cc = List.delete(cc, Pleroma.Constants.as_public())

      object =
        object
        |> Map.put("to", to)
        |> Map.put("cc", cc)

      activity =
        activity
        |> Map.put("to", to)
        |> Map.put("cc", cc)
        |> Map.put("object", object)

      {:ok, activity}
    else
      {:ok, activity}
    end
  end

  defp process_tag(
         "mrf_tag:disable-remote-subscription",
         %{"type" => "Follow", "actor" => actor} = activity
       ) do
    user = User.get_cached_by_ap_id(actor)

    if user.local == true do
      {:ok, activity}
    else
      {:reject,
       "[TagPolicy] Follow from #{actor} tagged with mrf_tag:disable-remote-subscription"}
    end
  end

  defp process_tag("mrf_tag:disable-any-subscription", %{"type" => "Follow", "actor" => actor}),
    do: {:reject, "[TagPolicy] Follow from #{actor} tagged with mrf_tag:disable-any-subscription"}

  defp process_tag(_, activity), do: {:ok, activity}

  def filter_activity(actor, activity) do
    User.get_cached_by_ap_id(actor)
    |> get_tags()
    |> Enum.reduce({:ok, activity}, fn
      tag, {:ok, activity} ->
        process_tag(tag, activity)

      _, error ->
        error
    end)
  end

  @impl true
  def filter(%{"object" => target_actor, "type" => "Follow"} = activity),
    do: filter_activity(target_actor, activity)

  @impl true
  def filter(%{"actor" => actor, "type" => type} = activity) when type in ["Create", "Update"],
    do: filter_activity(actor, activity)

  @impl true
  def filter(activity), do: {:ok, activity}

  @impl true
  def describe, do: {:ok, %{}}
end
