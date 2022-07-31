# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Feed.TagController do
  use Pleroma.Web, :controller

  alias Pleroma.Config
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.Feed.FeedView

  def feed(conn, params) do
    if Config.get!([:instance, :public]) do
      render_feed(conn, params)
    else
      render_error(conn, :not_found, "Not found")
    end
  end

  defp render_feed(conn, %{"tag" => raw_tag} = params) do
    {format, tag} = parse_tag(raw_tag)

    activities =
      %{type: ["Create"], tag: tag}
      |> Pleroma.Maps.put_if_present(:max_id, params["max_id"])
      |> ActivityPub.fetch_public_activities()

    conn
    |> put_resp_content_type("application/#{format}+xml")
    |> put_view(FeedView)
    |> render("tag.#{format}",
      activities: activities,
      tag: tag,
      feed_config: Config.get([:feed])
    )
  end

  @spec parse_tag(binary() | any()) :: {format :: String.t(), tag :: String.t()}
  defp parse_tag(raw_tag) do
    case is_binary(raw_tag) && Enum.reverse(String.split(raw_tag, ".")) do
      [format | tag] when format in ["rss", "atom"] ->
        {format, Enum.join(tag, ".")}

      _ ->
        {"atom", raw_tag}
    end
  end
end
