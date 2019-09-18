# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RuntimeStaticPlugTest do
  use Pleroma.Web.ConnCase

  @dir "test/tmp/instance_static"

  setup do
    File.mkdir_p!(@dir)
    on_exit(fn -> File.rm_rf(@dir) end)
  end

  clear_config([:instance, :static_dir]) do
    Pleroma.Config.put([:instance, :static_dir], @dir)
  end

  test "overrides index" do
    bundled_index = get(build_conn(), "/")
    assert html_response(bundled_index, 200) == File.read!("priv/static/index.html")

    File.write!(@dir <> "/index.html", "hello world")

    index = get(build_conn(), "/")
    assert html_response(index, 200) == "hello world"
  end

  test "overrides any file in static/static" do
    bundled_index = get(build_conn(), "/static/terms-of-service.html")

    assert html_response(bundled_index, 200) ==
             File.read!("priv/static/static/terms-of-service.html")

    File.mkdir!(@dir <> "/static")
    File.write!(@dir <> "/static/terms-of-service.html", "plz be kind")

    index = get(build_conn(), "/static/terms-of-service.html")
    assert html_response(index, 200) == "plz be kind"

    File.write!(@dir <> "/static/kaniini.html", "<h1>rabbit hugs as a service</h1>")
    index = get(build_conn(), "/static/kaniini.html")
    assert html_response(index, 200) == "<h1>rabbit hugs as a service</h1>"
  end
end
