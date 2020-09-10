# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.FrontendStaticPlugTest do
  alias Pleroma.Plugs.FrontendStatic
  use Pleroma.Web.ConnCase

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
      |> FrontendStatic.init()

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
end
