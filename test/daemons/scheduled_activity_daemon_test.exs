# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ScheduledActivityDaemonTest do
  use Pleroma.DataCase
  alias Pleroma.ScheduledActivity
  import Pleroma.Factory

  test "creates a status from the scheduled activity" do
    user = insert(:user)
    scheduled_activity = insert(:scheduled_activity, user: user, params: %{status: "hi"})
    Pleroma.Daemons.ScheduledActivityDaemon.perform(:execute, scheduled_activity.id)

    refute Repo.get(ScheduledActivity, scheduled_activity.id)
    activity = Repo.all(Pleroma.Activity) |> Enum.find(&(&1.actor == user.ap_id))
    assert Pleroma.Object.normalize(activity).data["content"] == "hi"
  end
end
