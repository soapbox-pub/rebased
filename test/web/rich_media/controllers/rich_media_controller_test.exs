# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.RichMediaControllerTest do
  use Pleroma.Web.ConnCase
  import Pleroma.Factory
  import Tesla.Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "GET /api/rich_media/parse" do
    setup do
      user = insert(:user)

      [user: user]
    end

    test "returns 404 if not metadata found", %{user: user} do
      build_conn()
      |> with_credentials(user.nickname, "test")
      |> get("/api/rich_media/parse", %{"url" => "http://example.com/empty"})
      |> json_response(404)
    end

    test "returns OGP metadata", %{user: user} do
      response =
        build_conn()
        |> with_credentials(user.nickname, "test")
        |> get("/api/rich_media/parse", %{"url" => "http://example.com/ogp"})
        |> json_response(200)

      assert response == %{
               "image" => "http://ia.media-imdb.com/images/rock.jpg",
               "title" => "The Rock",
               "type" => "video.movie",
               "url" => "http://www.imdb.com/title/tt0117500/"
             }
    end
  end

  defp with_credentials(conn, username, password) do
    header_content = "Basic " <> Base.encode64("#{username}:#{password}")
    put_req_header(conn, "authorization", header_content)
  end
end
