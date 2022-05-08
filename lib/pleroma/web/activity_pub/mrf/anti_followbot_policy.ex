# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.AntiFollowbotPolicy do
  alias Pleroma.User

  @moduledoc "Prevent followbots from following with a bit of heuristic"

  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  # XXX: this should become User.normalize_by_ap_id() or similar, really.
  defp normalize_by_ap_id(%{"id" => id}), do: User.get_cached_by_ap_id(id)
  defp normalize_by_ap_id(uri) when is_binary(uri), do: User.get_cached_by_ap_id(uri)
  defp normalize_by_ap_id(_), do: nil

  defp score_nickname("followbot@" <> _), do: 1.0
  defp score_nickname("federationbot@" <> _), do: 1.0
  defp score_nickname("federation_bot@" <> _), do: 1.0
  defp score_nickname(_), do: 0.0

  defp score_displayname("federation bot"), do: 1.0
  defp score_displayname("federationbot"), do: 1.0
  defp score_displayname("fedibot"), do: 1.0
  defp score_displayname(_), do: 0.0

  defp determine_if_followbot(%User{nickname: nickname, name: displayname, actor_type: actor_type}) do
    # nickname will be a binary string except when following a relay
    nick_score =
      if is_binary(nickname) do
        nickname
        |> String.downcase()
        |> score_nickname()
      else
        0.0
      end

    # displayname will either be a binary string or nil, if a displayname isn't set.
    name_score =
      if is_binary(displayname) do
        displayname
        |> String.downcase()
        |> score_displayname()
      else
        0.0
      end

    # actor_type "Service" is a Bot account
    actor_type_score =
      if actor_type == "Service" do
        1.0
      else
        0.0
      end

    nick_score + name_score + actor_type_score
  end

  defp determine_if_followbot(_), do: 0.0

  defp bot_allowed?(%{"object" => target}, bot_actor) do
    %User{} = user = normalize_by_ap_id(target)

    User.following?(user, bot_actor)
  end

  @impl true
  def filter(%{"type" => "Follow", "actor" => actor_id} = message) do
    %User{} = actor = normalize_by_ap_id(actor_id)

    score = determine_if_followbot(actor)

    if score < 0.8 || bot_allowed?(message, actor) do
      {:ok, message}
    else
      {:reject, "[AntiFollowbotPolicy] Scored #{actor_id} as #{score}"}
    end
  end

  @impl true
  def filter(message), do: {:ok, message}

  @impl true
  def describe, do: {:ok, %{}}
end
