# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.CustomEmojiControllerTest do
  use Pleroma.Web.ConnCase, async: true

  test "with tags", %{conn: conn} do
    assert resp =
             conn
             |> get("/api/v1/custom_emojis")
             |> json_response_and_validate_schema(200)

    assert [emoji | _body] = resp
    assert Map.has_key?(emoji, "shortcode")
    assert Map.has_key?(emoji, "static_url")
    assert Map.has_key?(emoji, "tags")
    assert is_list(emoji["tags"])
    assert Map.has_key?(emoji, "category")
    assert Map.has_key?(emoji, "url")
    assert Map.has_key?(emoji, "visible_in_picker")
  end
end
