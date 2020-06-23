# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.StatusViewTest do
  use Pleroma.DataCase

  alias Pleroma.Web.PleromaAPI.ScrobbleView

  import Pleroma.Factory

  test "successfully renders a Listen activity (pleroma extension)" do
    listen_activity = insert(:listen)

    status = ScrobbleView.render("show.json", activity: listen_activity)

    assert status.length == listen_activity.data["object"]["length"]
    assert status.title == listen_activity.data["object"]["title"]
  end
end
