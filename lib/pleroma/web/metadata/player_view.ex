# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.PlayerView do
  use Pleroma.Web, :view
  import Phoenix.HTML.Tag, only: [content_tag: 3, tag: 2]

  def render("player.html", %{"mediaType" => type, "href" => href}) do
    {tag_type, tag_attrs} =
      case type do
        "audio" <> _ -> {:audio, []}
        "video" <> _ -> {:video, [loop: true]}
      end

    content_tag(
      tag_type,
      [
        tag(:source, src: href, type: type),
        "Your browser does not support #{type} playback."
      ],
      [controls: true] ++ tag_attrs
    )
  end
end
