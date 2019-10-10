# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MediaProxy.MediaProxyControllerTest do
  use Pleroma.Web.ConnCase
  import Mock
  alias Pleroma.Config

  setup do
    media_proxy_config = Config.get([:media_proxy]) || []
    on_exit(fn -> Config.put([:media_proxy], media_proxy_config) end)
    :ok
  end

  test "it returns 404 when MediaProxy disabled", %{conn: conn} do
    Config.put([:media_proxy, :enabled], false)

    assert %Plug.Conn{
             status: 404,
             resp_body: "Not Found"
           } = get(conn, "/proxy/hhgfh/eeeee")

    assert %Plug.Conn{
             status: 404,
             resp_body: "Not Found"
           } = get(conn, "/proxy/hhgfh/eeee/fff")
  end

  test "it returns 403 when signature invalidated", %{conn: conn} do
    Config.put([:media_proxy, :enabled], true)
    Config.put([Pleroma.Web.Endpoint, :secret_key_base], "00000000000")
    path = URI.parse(Pleroma.Web.MediaProxy.encode_url("https://google.fn")).path
    Config.put([Pleroma.Web.Endpoint, :secret_key_base], "000")

    assert %Plug.Conn{
             status: 403,
             resp_body: "Forbidden"
           } = get(conn, path)

    assert %Plug.Conn{
             status: 403,
             resp_body: "Forbidden"
           } = get(conn, "/proxy/hhgfh/eeee")

    assert %Plug.Conn{
             status: 403,
             resp_body: "Forbidden"
           } = get(conn, "/proxy/hhgfh/eeee/fff")
  end

  test "redirects on valid url when filename invalidated", %{conn: conn} do
    Config.put([:media_proxy, :enabled], true)
    Config.put([Pleroma.Web.Endpoint, :secret_key_base], "00000000000")
    url = Pleroma.Web.MediaProxy.encode_url("https://google.fn/test.png")
    invalid_url = String.replace(url, "test.png", "test-file.png")
    response = get(conn, invalid_url)
    html = "<html><body>You are being <a href=\"#{url}\">redirected</a>.</body></html>"
    assert response.status == 302
    assert response.resp_body == html
  end

  test "it performs ReverseProxy.call when signature valid", %{conn: conn} do
    Config.put([:media_proxy, :enabled], true)
    Config.put([Pleroma.Web.Endpoint, :secret_key_base], "00000000000")
    url = Pleroma.Web.MediaProxy.encode_url("https://google.fn/test.png")

    with_mock Pleroma.ReverseProxy,
      call: fn _conn, _url, _opts -> %Plug.Conn{status: :success} end do
      assert %Plug.Conn{status: :success} = get(conn, url)
    end
  end
end
