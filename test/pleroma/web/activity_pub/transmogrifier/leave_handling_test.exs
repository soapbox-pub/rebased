# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.LeaveHandlingTest do
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.Pipeline
  alias Pleroma.Web.ActivityPub.SideEffects
  alias Pleroma.Web.ActivityPub.Transmogrifier

  import Pleroma.Factory

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "handle_incoming" do
    test "it works for incoming Mobilizon leaves" do
      user = insert(:user)

      event = insert(:event)

      {:ok, join_activity, _} = Builder.join(user, event)
      {:ok, join_activity, _} = Pipeline.common_pipeline(join_activity, local: true)
      {:ok, _, _} = SideEffects.handle(join_activity, local: true)

      event = Object.get_by_id(event.id)

      assert length(event.data["participations"]) === 1

      leave_data =
        File.read!("test/fixtures/tesla_mock/mobilizon-event-leave.json")
        |> Jason.decode!()
        |> Map.put("actor", user.ap_id)
        |> Map.put("object", event.data["id"])

      {:ok, %Activity{local: false} = _activity} = Transmogrifier.handle_incoming(leave_data)

      event = Object.get_by_id(event.id)

      assert length(event.data["participations"]) === 0
      refute Repo.get(Activity, join_activity.id)
    end
  end
end
