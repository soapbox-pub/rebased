# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.AppViewTest do
  use Pleroma.DataCase, async: true
  alias Pleroma.Web.PleromaAPI.AppView
  import Pleroma.Factory

  test "index.json" do
    apps = [
      insert(:oauth_app),
      insert(:oauth_app),
      insert(:oauth_app)
    ]

    results = AppView.render("index.json", %{apps: apps})

    assert [%{client_id: _, client_secret: _}, _, _] = results
  end
end
