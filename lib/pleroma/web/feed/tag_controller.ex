# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Feed.TagController do
  use Pleroma.Web, :controller

  alias Pleroma.Config
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.Feed.FeedView

  import Pleroma.Web.ControllerHelper, only: [put_in_if_exist: 3]

  def feed(conn, %{"tag" => raw_tag} = params) do
    tag = parse_tag(raw_tag)

    activities =
      %{"type" => ["Create"], "whole_db" => true, "tag" => tag}
      |> put_in_if_exist("max_id", params["max_id"])
      |> ActivityPub.fetch_public_activities()

    conn
    |> put_resp_content_type("application/atom+xml")
    |> put_view(FeedView)
    |> render("tag.xml",
      activities: activities,
      tag: tag,
      feed_config: Config.get([:feed])
    )
  end

  defp parse_tag(raw_tag) when is_binary(raw_tag) do
    case Enum.reverse(String.split(raw_tag, ".")) do
      [format | tag] when format in ["atom", "rss"] -> Enum.join(tag, ".")
      _ -> raw_tag
    end
  end

  defp parse_tag(raw_tag), do: raw_tag
end
