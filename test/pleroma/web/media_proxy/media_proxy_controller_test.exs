# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MediaProxy.MediaProxyControllerTest do
  use Pleroma.Web.ConnCase

  import Mock

  alias Pleroma.Web.MediaProxy
  alias Plug.Conn

  describe "Media Proxy" do
    setup do
      clear_config([:media_proxy, :enabled], true)
      clear_config([Pleroma.Web.Endpoint, :secret_key_base], "00000000000")

      [url: MediaProxy.encode_url("https://google.fn/test.png")]
    end

    test "it returns 404 when disabled", %{conn: conn} do
      clear_config([:media_proxy, :enabled], false)

      assert %Conn{
               status: 404,
               resp_body: "Not Found"
             } = get(conn, "/proxy/hhgfh/eeeee")

      assert %Conn{
               status: 404,
               resp_body: "Not Found"
             } = get(conn, "/proxy/hhgfh/eeee/fff")
    end

    test "it returns 403 for invalid signature", %{conn: conn, url: url} do
      clear_config([Pleroma.Web.Endpoint, :secret_key_base], "000")
      %{path: path} = URI.parse(url)

      assert %Conn{
               status: 403,
               resp_body: "Forbidden"
             } = get(conn, path)

      assert %Conn{
               status: 403,
               resp_body: "Forbidden"
             } = get(conn, "/proxy/hhgfh/eeee")

      assert %Conn{
               status: 403,
               resp_body: "Forbidden"
             } = get(conn, "/proxy/hhgfh/eeee/fff")
    end

    test "redirects to valid url when filename is invalidated", %{conn: conn, url: url} do
      invalid_url = String.replace(url, "test.png", "test-file.png")
      response = get(conn, invalid_url)
      assert response.status == 302
      assert redirected_to(response) == url
    end

    test "it performs ReverseProxy.call with valid signature", %{conn: conn, url: url} do
      with_mock Pleroma.ReverseProxy,
        call: fn _conn, _url, _opts -> %Conn{status: :success} end do
        assert %Conn{status: :success} = get(conn, url)
      end
    end

    test "it returns 404 when url is in banned_urls cache", %{conn: conn, url: url} do
      MediaProxy.put_in_banned_urls("https://google.fn/test.png")

      with_mock Pleroma.ReverseProxy,
        call: fn _conn, _url, _opts -> %Conn{status: :success} end do
        assert %Conn{status: 404, resp_body: "Not Found"} = get(conn, url)
      end
    end
  end

  describe "Media Preview Proxy" do
    def assert_dependencies_installed do
      missing_dependencies = Pleroma.Helpers.MediaHelper.missing_dependencies()

      assert missing_dependencies == [],
             "Error: missing dependencies (please refer to `docs/installation`): #{inspect(missing_dependencies)}"
    end

    setup do
      clear_config([:media_proxy, :enabled], true)
      clear_config([:media_preview_proxy, :enabled], true)
      clear_config([Pleroma.Web.Endpoint, :secret_key_base], "00000000000")

      original_url = "https://google.fn/test.png"

      [
        url: MediaProxy.encode_preview_url(original_url),
        media_proxy_url: MediaProxy.encode_url(original_url)
      ]
    end

    test "returns 404 when media proxy is disabled", %{conn: conn} do
      clear_config([:media_proxy, :enabled], false)

      assert %Conn{
               status: 404,
               resp_body: "Not Found"
             } = get(conn, "/proxy/preview/hhgfh/eeeee")

      assert %Conn{
               status: 404,
               resp_body: "Not Found"
             } = get(conn, "/proxy/preview/hhgfh/fff")
    end

    test "returns 404 when disabled", %{conn: conn} do
      clear_config([:media_preview_proxy, :enabled], false)

      assert %Conn{
               status: 404,
               resp_body: "Not Found"
             } = get(conn, "/proxy/preview/hhgfh/eeeee")

      assert %Conn{
               status: 404,
               resp_body: "Not Found"
             } = get(conn, "/proxy/preview/hhgfh/fff")
    end

    test "it returns 403 for invalid signature", %{conn: conn, url: url} do
      clear_config([Pleroma.Web.Endpoint, :secret_key_base], "000")
      %{path: path} = URI.parse(url)

      assert %Conn{
               status: 403,
               resp_body: "Forbidden"
             } = get(conn, path)

      assert %Conn{
               status: 403,
               resp_body: "Forbidden"
             } = get(conn, "/proxy/preview/hhgfh/eeee")

      assert %Conn{
               status: 403,
               resp_body: "Forbidden"
             } = get(conn, "/proxy/preview/hhgfh/eeee/fff")
    end

    test "redirects to valid url when filename is invalidated", %{conn: conn, url: url} do
      invalid_url = String.replace(url, "test.png", "test-file.png")
      response = get(conn, invalid_url)
      assert response.status == 302
      assert redirected_to(response) == url
    end

    test "responds with 424 Failed Dependency if HEAD request to media proxy fails", %{
      conn: conn,
      url: url,
      media_proxy_url: media_proxy_url
    } do
      Tesla.Mock.mock(fn
        %{method: "HEAD", url: ^media_proxy_url} ->
          %Tesla.Env{status: 500, body: ""}
      end)

      response = get(conn, url)
      assert response.status == 424
      assert response.resp_body == "Can't fetch HTTP headers (HTTP 500)."
    end

    test "redirects to media proxy URI on unsupported content type", %{
      conn: conn,
      url: url,
      media_proxy_url: media_proxy_url
    } do
      Tesla.Mock.mock(fn
        %{method: "HEAD", url: ^media_proxy_url} ->
          %Tesla.Env{status: 200, body: "", headers: [{"content-type", "application/pdf"}]}
      end)

      response = get(conn, url)
      assert response.status == 302
      assert redirected_to(response) == media_proxy_url
    end

    test "with `static=true` and GIF image preview requested, responds with JPEG image", %{
      conn: conn,
      url: url,
      media_proxy_url: media_proxy_url
    } do
      assert_dependencies_installed()

      # Setting a high :min_content_length to ensure this scenario is not affected by its logic
      clear_config([:media_preview_proxy, :min_content_length], 1_000_000_000)

      Tesla.Mock.mock(fn
        %{method: "HEAD", url: ^media_proxy_url} ->
          %Tesla.Env{
            status: 200,
            body: "",
            headers: [{"content-type", "image/gif"}, {"content-length", "1001718"}]
          }

        %{method: :get, url: ^media_proxy_url} ->
          %Tesla.Env{status: 200, body: File.read!("test/fixtures/image.gif")}
      end)

      response = get(conn, url <> "?static=true")

      assert response.status == 200
      assert Conn.get_resp_header(response, "content-type") == ["image/jpeg"]
      assert response.resp_body != ""
    end

    test "with GIF image preview requested and no `static` param, redirects to media proxy URI",
         %{
           conn: conn,
           url: url,
           media_proxy_url: media_proxy_url
         } do
      Tesla.Mock.mock(fn
        %{method: "HEAD", url: ^media_proxy_url} ->
          %Tesla.Env{status: 200, body: "", headers: [{"content-type", "image/gif"}]}
      end)

      response = get(conn, url)

      assert response.status == 302
      assert redirected_to(response) == media_proxy_url
    end

    test "with `static` param and non-GIF image preview requested, " <>
           "redirects to media preview proxy URI without `static` param",
         %{
           conn: conn,
           url: url,
           media_proxy_url: media_proxy_url
         } do
      Tesla.Mock.mock(fn
        %{method: "HEAD", url: ^media_proxy_url} ->
          %Tesla.Env{status: 200, body: "", headers: [{"content-type", "image/jpeg"}]}
      end)

      response = get(conn, url <> "?static=true")

      assert response.status == 302
      assert redirected_to(response) == url
    end

    test "with :min_content_length setting not matched by Content-Length header, " <>
           "redirects to media proxy URI",
         %{
           conn: conn,
           url: url,
           media_proxy_url: media_proxy_url
         } do
      clear_config([:media_preview_proxy, :min_content_length], 100_000)

      Tesla.Mock.mock(fn
        %{method: "HEAD", url: ^media_proxy_url} ->
          %Tesla.Env{
            status: 200,
            body: "",
            headers: [{"content-type", "image/gif"}, {"content-length", "5000"}]
          }
      end)

      response = get(conn, url)

      assert response.status == 302
      assert redirected_to(response) == media_proxy_url
    end

    test "thumbnails PNG images into PNG", %{
      conn: conn,
      url: url,
      media_proxy_url: media_proxy_url
    } do
      assert_dependencies_installed()

      Tesla.Mock.mock(fn
        %{method: "HEAD", url: ^media_proxy_url} ->
          %Tesla.Env{status: 200, body: "", headers: [{"content-type", "image/png"}]}

        %{method: :get, url: ^media_proxy_url} ->
          %Tesla.Env{status: 200, body: File.read!("test/fixtures/image.png")}
      end)

      response = get(conn, url)

      assert response.status == 200
      assert Conn.get_resp_header(response, "content-type") == ["image/png"]
      assert response.resp_body != ""
    end

    test "thumbnails JPEG images into JPEG", %{
      conn: conn,
      url: url,
      media_proxy_url: media_proxy_url
    } do
      assert_dependencies_installed()

      Tesla.Mock.mock(fn
        %{method: "HEAD", url: ^media_proxy_url} ->
          %Tesla.Env{status: 200, body: "", headers: [{"content-type", "image/jpeg"}]}

        %{method: :get, url: ^media_proxy_url} ->
          %Tesla.Env{status: 200, body: File.read!("test/fixtures/image.jpg")}
      end)

      response = get(conn, url)

      assert response.status == 200
      assert Conn.get_resp_header(response, "content-type") == ["image/jpeg"]
      assert response.resp_body != ""
    end

    test "redirects to media proxy URI in case of thumbnailing error", %{
      conn: conn,
      url: url,
      media_proxy_url: media_proxy_url
    } do
      Tesla.Mock.mock(fn
        %{method: "HEAD", url: ^media_proxy_url} ->
          %Tesla.Env{status: 200, body: "", headers: [{"content-type", "image/jpeg"}]}

        %{method: :get, url: ^media_proxy_url} ->
          %Tesla.Env{status: 200, body: "<html><body>error</body></html>"}
      end)

      response = get(conn, url)

      assert response.status == 302
      assert redirected_to(response) == media_proxy_url
    end
  end
end
