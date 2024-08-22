# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.AntiMentionSpamPolicy do
  alias Pleroma.Config
  alias Pleroma.User
  require Pleroma.Constants

  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  defp user_has_posted?(%User{} = u), do: u.note_count > 0

  defp user_has_age?(%User{} = u) do
    user_age_limit = Config.get([:mrf_antimentionspam, :user_age_limit], 30_000)
    diff = NaiveDateTime.utc_now() |> NaiveDateTime.diff(u.inserted_at, :millisecond)
    diff >= user_age_limit
  end

  defp good_reputation?(%User{} = u) do
    user_has_age?(u) and user_has_posted?(u)
  end

  # copied from HellthreadPolicy
  defp get_recipient_count(activity) do
    recipients = (activity["to"] || []) ++ (activity["cc"] || [])

    follower_collection =
      User.get_cached_by_ap_id(activity["actor"] || activity["attributedTo"]).follower_address

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

  defp object_has_recipients?(%{"object" => object} = activity) do
    {_, object_count} = get_recipient_count(object)
    {_, activity_count} = get_recipient_count(activity)
    object_count + activity_count > 0
  end

  defp object_has_recipients?(object) do
    {_, count} = get_recipient_count(object)
    count > 0
  end

  @impl true
  def filter(%{"type" => "Create", "actor" => actor} = activity) do
    with {:ok, %User{local: false} = u} <- User.get_or_fetch_by_ap_id(actor),
         {:has_mentions, true} <- {:has_mentions, object_has_recipients?(activity)},
         {:good_reputation, true} <- {:good_reputation, good_reputation?(u)} do
      {:ok, activity}
    else
      {:ok, %User{local: true}} ->
        {:ok, activity}

      {:has_mentions, false} ->
        {:ok, activity}

      {:good_reputation, false} ->
        {:reject, "[AntiMentionSpamPolicy] User rejected"}

      {:error, _} ->
        {:reject, "[AntiMentionSpamPolicy] Failed to get or fetch user by ap_id"}

      e ->
        {:reject, "[AntiMentionSpamPolicy] Unhandled error #{inspect(e)}"}
    end
  end

  # in all other cases, pass through
  def filter(activity), do: {:ok, activity}

  @impl true
  def describe, do: {:ok, %{}}
end
