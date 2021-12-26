# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ManifestControllerTest do
  use Pleroma.Web.ConnCase

  setup do
    clear_config([:instance, :name], "Manifest Test")
    clear_config([:manifest, :theme_color], "#ff0000")
  end

  test "manifest.json", %{conn: conn} do
    conn = get(conn, "/manifest.json")
    assert %{"name" => "Manifest Test", "theme_color" => "#ff0000"} = json_response(conn, 200)
  end
end
