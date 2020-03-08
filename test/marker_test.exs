# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.MarkerTest do
  use Pleroma.DataCase
  alias Pleroma.Marker

  import Pleroma.Factory

  describe "get_markers/2" do
    test "returns user markers" do
      user = insert(:user)
      marker = insert(:marker, user: user)
      insert(:marker, timeline: "home", user: user)
      assert Marker.get_markers(user, ["notifications"]) == [refresh_record(marker)]
    end
  end

  describe "upsert/2" do
    test "creates a marker" do
      user = insert(:user)

      {:ok, %{"notifications" => %Marker{} = marker}} =
        Marker.upsert(
          user,
          %{"notifications" => %{"last_read_id" => "34"}}
        )

      assert marker.timeline == "notifications"
      assert marker.last_read_id == "34"
      assert marker.lock_version == 0
    end

    test "updates exist marker" do
      user = insert(:user)
      marker = insert(:marker, user: user, last_read_id: "8909")

      {:ok, %{"notifications" => %Marker{}}} =
        Marker.upsert(
          user,
          %{"notifications" => %{"last_read_id" => "9909"}}
        )

      marker = refresh_record(marker)
      assert marker.timeline == "notifications"
      assert marker.last_read_id == "9909"
      assert marker.lock_version == 0
    end
  end
end
