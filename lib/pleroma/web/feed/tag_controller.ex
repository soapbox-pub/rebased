# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Feed.TagController do
  use Pleroma.Web, :controller

  alias Pleroma.Config
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.Feed.FeedView

  import Pleroma.Web.ControllerHelper, only: [put_if_exist: 3]

  def feed(conn, %{"tag" => raw_tag} = params) do
    {format, tag} = parse_tag(raw_tag)

    activities =
      %{"type" => ["Create"], "tag" => tag}
      |> put_if_exist("max_id", params["max_id"])
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
  defp parse_tag(raw_tag) when is_binary(raw_tag) do
    case Enum.reverse(String.split(raw_tag, ".")) do
      [format | tag] when format in ["atom", "rss"] -> {format, Enum.join(tag, ".")}
      _ -> {"rss", raw_tag}
    end
  end

  defp parse_tag(raw_tag), do: {"rss", raw_tag}
end
