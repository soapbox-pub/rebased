# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MarkerViewTest do
  use Pleroma.DataCase
  alias Pleroma.Web.MastodonAPI.MarkerView
  import Pleroma.Factory

  test "returns markers" do
    marker1 = insert(:marker, timeline: "notifications", last_read_id: "17")
    marker2 = insert(:marker, timeline: "home", last_read_id: "42")

    assert MarkerView.render("markers.json", %{markers: [marker1, marker2]}) == %{
             "home" => %{
               last_read_id: "42",
               updated_at: NaiveDateTime.to_iso8601(marker2.updated_at),
               version: 0
             },
             "notifications" => %{
               last_read_id: "17",
               updated_at: NaiveDateTime.to_iso8601(marker1.updated_at),
               version: 0
             }
           }
  end
end
