# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.FrontendStaticPlugTest do
  use Pleroma.Web.ConnCase
  import Mock

  @dir "test/tmp/instance_static"

  setup do
    File.mkdir_p!(@dir)
    on_exit(fn -> File.rm_rf(@dir) end)
  end

  setup do: clear_config([:instance, :static_dir], @dir)

  test "init will give a static plug config + the frontend type" do
    opts =
      [
        at: "/admin",
        frontend_type: :admin
      ]
      |> Pleroma.Web.Plugs.FrontendStatic.init()

    assert opts[:at] == ["admin"]
    assert opts[:frontend_type] == :admin
  end

  test "overrides existing static files", %{conn: conn} do
    name = "pelmora"
    ref = "uguu"

    clear_config([:frontends, :primary], %{"name" => name, "ref" => ref})
    path = "#{@dir}/frontends/#{name}/#{ref}"

    File.mkdir_p!(path)
    File.write!("#{path}/index.html", "from frontend plug")

    index = get(conn, "/")
    assert html_response(index, 200) == "from frontend plug"
  end

  test "overrides existing static files for the `pleroma/admin` path", %{conn: conn} do
    name = "pelmora"
    ref = "uguu"

    clear_config([:frontends, :admin], %{"name" => name, "ref" => ref})
    path = "#{@dir}/frontends/#{name}/#{ref}"

    File.mkdir_p!(path)
    File.write!("#{path}/index.html", "from frontend plug")

    index = get(conn, "/pleroma/admin/")
    assert html_response(index, 200) == "from frontend plug"
  end

  test "exclude invalid path", %{conn: conn} do
    name = "pleroma-fe"
    ref = "dist"
    clear_config([:media_proxy, :enabled], true)
    clear_config([Pleroma.Web.Endpoint, :secret_key_base], "00000000000")
    clear_config([:frontends, :primary], %{"name" => name, "ref" => ref})
    path = "#{@dir}/frontends/#{name}/#{ref}"

    File.mkdir_p!("#{path}/proxy/rr/ss")
    File.write!("#{path}/proxy/rr/ss/Ek7w8WPVcAApOvN.jpg:large", "FB image")

    url =
      Pleroma.Web.MediaProxy.encode_url("https://pbs.twimg.com/media/Ek7w8WPVcAApOvN.jpg:large")

    with_mock Pleroma.ReverseProxy,
      call: fn _conn, _url, _opts -> %Plug.Conn{status: :success} end do
      assert %Plug.Conn{status: :success} = get(conn, url)
    end
  end

  test "api routes are detected correctly" do
    # If this test fails we have probably added something
    # new that should be in /api/ instead
    expected_routes = [
      "api",
      "main",
      "ostatus_subscribe",
      "oauth",
      "objects",
      "activities",
      "notice",
      "@:nickname",
      ":nickname",
      "users",
      "tags",
      "mailer",
      "inbox",
      "relay",
      "internal",
      ".well-known",
      "nodeinfo",
      "manifest.json",
      "auth",
      "proxy",
      "phoenix",
      "test",
      "user_exists",
      "check_password"
    ]

    assert expected_routes == Pleroma.Web.Router.get_api_routes()
  end
end
