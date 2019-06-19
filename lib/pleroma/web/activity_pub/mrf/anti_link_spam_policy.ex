# Pleroma: A lightweight social networking server
# Copyright © 2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.AntiLinkSpamPolicy do
  alias Pleroma.User

  require Logger

  # has the user successfully posted before?
  defp user_has_posted_before?(%User{} = u) do
    u.info.note_count > 0 || u.info.follower_count > 0
  end

  # does the post contain links?
  defp contains_links?(%{"content" => content} = _object) do
    content
    |> Floki.filter_out("a.mention,a.hashtag,a[rel~=\"tag\"],a.zrl")
    |> Floki.attribute("a", "href")
    |> length() > 0
  end

  def filter(%{"type" => "Create", "actor" => actor, "object" => object} = message) do
    with {:ok, %User{} = u} <- User.get_or_fetch_by_ap_id(actor),
         {:contains_links, true} <- {:contains_links, contains_links?(object)},
         {:posted_before, true} <- {:posted_before, user_has_posted_before?(u)} do
      {:ok, message}
    else
      {:contains_links, false} ->
        {:ok, message}

      {:posted_before, false} ->
        {:reject, nil}

      {:error, _} ->
        {:reject, nil}

      e ->
        Logger.warn("[MRF anti-link-spam] WTF: unhandled error #{inspect(e)}")
        {:reject, nil}
    end
  end

  # in all other cases, pass through
  def filter(message), do: {:ok, message}
end
