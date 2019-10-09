# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.CountStatusesTest do
  use Pleroma.DataCase

  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  import ExUnit.CaptureIO, only: [capture_io: 1]
  import Pleroma.Factory

  test "counts statuses" do
    user = insert(:user)
    {:ok, _} = CommonAPI.post(user, %{"status" => "test"})
    {:ok, _} = CommonAPI.post(user, %{"status" => "test2"})

    user2 = insert(:user)
    {:ok, _} = CommonAPI.post(user2, %{"status" => "test3"})

    user = refresh_record(user)
    user2 = refresh_record(user2)

    assert %{info: %{note_count: 2}} = user
    assert %{info: %{note_count: 1}} = user2

    {:ok, user} = User.update_info(user, &User.Info.set_note_count(&1, 0))
    {:ok, user2} = User.update_info(user2, &User.Info.set_note_count(&1, 0))

    assert %{info: %{note_count: 0}} = user
    assert %{info: %{note_count: 0}} = user2

    assert capture_io(fn -> Mix.Tasks.Pleroma.CountStatuses.run([]) end) == "Done\n"

    assert %{info: %{note_count: 2}} = refresh_record(user)
    assert %{info: %{note_count: 1}} = refresh_record(user2)
  end
end
