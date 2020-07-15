# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MediaProxy.MediaProxyControllerTest do
  use Pleroma.Web.ConnCase

  import Mock

  alias Pleroma.Web.MediaProxy
  alias Pleroma.Web.MediaProxy.MediaProxyController
  alias Plug.Conn

  setup do
    on_exit(fn -> Cachex.clear(:banned_urls_cache) end)
  end

  test "it returns 404 when MediaProxy disabled", %{conn: conn} do
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

  describe "" do
    setup do
      clear_config([:media_proxy, :enabled], true)
      clear_config([Pleroma.Web.Endpoint, :secret_key_base], "00000000000")
      [url: MediaProxy.encode_url("https://google.fn/test.png")]
    end

    test "it returns 403 for invalid signature", %{conn: conn, url: url} do
      Pleroma.Config.put([Pleroma.Web.Endpoint, :secret_key_base], "000")
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

    test "redirects on valid url when filename is invalidated", %{conn: conn, url: url} do
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

  describe "filename_matches/3" do
    test "preserves the encoded or decoded path" do
      assert MediaProxyController.filename_matches(
               %{"filename" => "/Hello world.jpg"},
               "/Hello world.jpg",
               "http://pleroma.social/Hello world.jpg"
             ) == :ok

      assert MediaProxyController.filename_matches(
               %{"filename" => "/Hello%20world.jpg"},
               "/Hello%20world.jpg",
               "http://pleroma.social/Hello%20world.jpg"
             ) == :ok

      assert MediaProxyController.filename_matches(
               %{"filename" => "/my%2Flong%2Furl%2F2019%2F07%2FS.jpg"},
               "/my%2Flong%2Furl%2F2019%2F07%2FS.jpg",
               "http://pleroma.social/my%2Flong%2Furl%2F2019%2F07%2FS.jpg"
             ) == :ok

      assert MediaProxyController.filename_matches(
               %{"filename" => "/my%2Flong%2Furl%2F2019%2F07%2FS.jp"},
               "/my%2Flong%2Furl%2F2019%2F07%2FS.jp",
               "http://pleroma.social/my%2Flong%2Furl%2F2019%2F07%2FS.jpg"
             ) == {:wrong_filename, "my%2Flong%2Furl%2F2019%2F07%2FS.jpg"}
    end

    test "encoded url are tried to match for proxy as `conn.request_path` encodes the url" do
      # conn.request_path will return encoded url
      request_path = "/ANALYSE-DAI-_-LE-STABLECOIN-100-D%C3%89CENTRALIS%C3%89-BQ.jpg"

      assert MediaProxyController.filename_matches(
               true,
               request_path,
               "https://mydomain.com/uploads/2019/07/ANALYSE-DAI-_-LE-STABLECOIN-100-DÉCENTRALISÉ-BQ.jpg"
             ) == :ok
    end
  end
end
