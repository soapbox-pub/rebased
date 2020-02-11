# Pleroma: A lightweight social networking server
# Copyright © 2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.AntiLinkSpamPolicy do
  alias Pleroma.User

  @behaviour Pleroma.Web.ActivityPub.MRF

  require Logger

  # has the user successfully posted before?
  defp old_user?(%User{} = u) do
    u.note_count > 0 || u.follower_count > 0
  end

  # does the post contain links?
  defp contains_links?(%{"content" => content} = _object) do
    content
    |> Floki.filter_out("a.mention,a.hashtag,a[rel~=\"tag\"],a.zrl")
    |> Floki.attribute("a", "href")
    |> length() > 0
  end

  defp contains_links?(_), do: false

  @impl true
  def filter(%{"type" => "Create", "actor" => actor, "object" => object} = message) do
    with {:ok, %User{} = u} <- User.get_or_fetch_by_ap_id(actor),
         {:contains_links, true} <- {:contains_links, contains_links?(object)},
         {:old_user, true} <- {:old_user, old_user?(u)} do
      {:ok, message}
    else
      {:contains_links, false} ->
        {:ok, message}

      {:old_user, false} ->
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

  @impl true
  def describe, do: {:ok, %{}}
end
