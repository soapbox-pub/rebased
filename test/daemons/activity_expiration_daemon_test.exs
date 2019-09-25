# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ActivityExpirationWorkerTest do
  use Pleroma.DataCase
  alias Pleroma.Activity
  import Pleroma.Factory

  test "deletes an activity" do
    activity = insert(:note_activity)
    expiration = insert(:expiration_in_the_past, %{activity_id: activity.id})
    Pleroma.Daemons.ActivityExpirationDaemon.perform(:execute, expiration.id)

    refute Repo.get(Activity, activity.id)
  end
end
