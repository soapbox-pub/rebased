# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.CustomEmojiControllerTest do
  use Pleroma.Web.ConnCase, async: true
  alias Pleroma.Web.ApiSpec
  alias Pleroma.Web.ApiSpec.Schemas.CustomEmoji
  alias Pleroma.Web.ApiSpec.Schemas.CustomEmojisResponse
  import OpenApiSpex.TestAssertions

  test "with tags", %{conn: conn} do
    assert resp =
             conn
             |> get("/api/v1/custom_emojis")
             |> json_response(200)

    assert [emoji | _body] = resp
    assert Map.has_key?(emoji, "shortcode")
    assert Map.has_key?(emoji, "static_url")
    assert Map.has_key?(emoji, "tags")
    assert is_list(emoji["tags"])
    assert Map.has_key?(emoji, "category")
    assert Map.has_key?(emoji, "url")
    assert Map.has_key?(emoji, "visible_in_picker")
    assert_schema(resp, "CustomEmojisResponse", ApiSpec.spec())
    assert_schema(emoji, "CustomEmoji", ApiSpec.spec())
  end

  test "CustomEmoji example matches schema" do
    api_spec = ApiSpec.spec()
    schema = CustomEmoji.schema()
    assert_schema(schema.example, "CustomEmoji", api_spec)
  end

  test "CustomEmojisResponse example matches schema" do
    api_spec = ApiSpec.spec()
    schema = CustomEmojisResponse.schema()
    assert_schema(schema.example, "CustomEmojisResponse", api_spec)
  end
end
