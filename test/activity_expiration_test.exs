# Pleroma: A lightweight social networking server
# Copyright © 2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ActivityExpirationTest do
  use Pleroma.DataCase
  alias Pleroma.ActivityExpiration
  import Pleroma.Factory

  test "finds activities due to be deleted only" do
    activity = insert(:note_activity)
    expiration_due = insert(:expiration_in_the_past, %{activity_id: activity.id})
    activity2 = insert(:note_activity)
    insert(:expiration_in_the_future, %{activity_id: activity2.id})

    expirations = ActivityExpiration.due_expirations()

    assert length(expirations) == 1
    assert hd(expirations) == expiration_due
  end

  test "denies expirations that don't live long enough" do
    activity = insert(:note_activity)
    now = NaiveDateTime.utc_now()
    assert {:error, _} = ActivityExpiration.create(activity, now)
  end
end
