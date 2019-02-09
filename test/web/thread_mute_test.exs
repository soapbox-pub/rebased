# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ThreadMuteTest do
  use Pleroma.DataCase
  import Pleroma.Web.ThreadMute

  import Pleroma.Factory

  test "add a mute" do
    user = insert(:user, %{id: "1"})

    activity =
      insert(:note_activity, %{
        data: %{"context" => "http://localhost:4000/contexts/361ca23e-ffa7-4773-b981-a355a18dc592"}
      })

    id = activity.id
    {:ok, mute} = add_mute(user, id)

    assert mute.user_id == "1"
    assert mute.context == "http://localhost:4000/contexts/361ca23e-ffa7-4773-b981-a355a18dc592"
  end
end
