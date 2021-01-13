# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.ScrobbleViewTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.PleromaAPI.ScrobbleView

  import Pleroma.Factory

  test "successfully renders a Listen activity (pleroma extension)" do
    listen_activity = insert(:listen)

    status = ScrobbleView.render("show.json", activity: listen_activity)

    assert status.length == listen_activity.data["object"]["length"]
    assert status.title == listen_activity.data["object"]["title"]
  end
end
