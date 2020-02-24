# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.RefreshCounterCacheTest do
  use Pleroma.DataCase
  alias Pleroma.Web.CommonAPI
  import ExUnit.CaptureIO, only: [capture_io: 1]
  import Pleroma.Factory

  test "counts statuses" do
    user = insert(:user)
    other_user = insert(:user)

    CommonAPI.post(user, %{"visibility" => "public", "status" => "hey"})

    Enum.each(0..1, fn _ ->
      CommonAPI.post(user, %{
        "visibility" => "unlisted",
        "status" => "hey"
      })
    end)

    Enum.each(0..2, fn _ ->
      CommonAPI.post(user, %{
        "visibility" => "direct",
        "status" => "hey @#{other_user.nickname}"
      })
    end)

    Enum.each(0..3, fn _ ->
      CommonAPI.post(user, %{
        "visibility" => "private",
        "status" => "hey"
      })
    end)

    assert capture_io(fn -> Mix.Tasks.Pleroma.RefreshCounterCache.run([]) end) =~ "Done\n"

    assert %{direct: 3, private: 4, public: 1, unlisted: 2} =
             Pleroma.Stats.get_status_visibility_count()
  end
end
