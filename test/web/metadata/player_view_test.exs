# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.PlayerViewTest do
  use Pleroma.DataCase

  alias Pleroma.Web.Metadata.PlayerView

  test "it renders audio tag" do
    res =
      PlayerView.render(
        "player.html",
        %{"mediaType" => "audio", "href" => "test-href"}
      )
      |> Phoenix.HTML.safe_to_string()

    assert res ==
             "<audio controls><source src=\"test-href\" type=\"audio\">Your browser does not support audio playback.</audio>"
  end

  test "it renders videos tag" do
    res =
      PlayerView.render(
        "player.html",
        %{"mediaType" => "video", "href" => "test-href"}
      )
      |> Phoenix.HTML.safe_to_string()

    assert res ==
             "<video controls loop><source src=\"test-href\" type=\"video\">Your browser does not support video playback.</video>"
  end
end
