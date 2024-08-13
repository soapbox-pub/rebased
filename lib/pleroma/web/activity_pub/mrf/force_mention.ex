# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.ForceMention do
  require Pleroma.Constants

  alias Pleroma.Config
  alias Pleroma.Object
  alias Pleroma.User

  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  defp get_author(url) do
    with %Object{data: %{"actor" => actor}} <- Object.normalize(url, fetch: false),
         %User{ap_id: ap_id, nickname: nickname} <- User.get_cached_by_ap_id(actor) do
      %{"type" => "Mention", "href" => ap_id, "name" => "@#{nickname}"}
    else
      _ -> nil
    end
  end

  defp prepend_author(tags, _, false), do: tags

  defp prepend_author(tags, nil, _), do: tags

  defp prepend_author(tags, url, _) do
    actor = get_author(url)

    if not is_nil(actor) do
      [actor | tags]
    else
      tags
    end
  end

  @impl true
  def filter(%{"type" => "Create", "object" => %{"tag" => tag} = object} = activity) do
    tag =
      tag
      |> prepend_author(
        object["inReplyTo"],
        Config.get([:mrf_force_mention, :mention_parent, true])
      )
      |> prepend_author(
        object["quoteUrl"],
        Config.get([:mrf_force_mention, :mention_quoted, true])
      )
      |> Enum.uniq()

    {:ok, put_in(activity["object"]["tag"], tag)}
  end

  @impl true
  def filter(activity), do: {:ok, activity}

  @impl true
  def describe, do: {:ok, %{}}
end
