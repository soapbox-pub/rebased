# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.JoinHandlingTest do
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.Web.ActivityPub.Transmogrifier

  import Pleroma.Factory
  import Ecto.Query

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "handle_incoming" do
    test "it works for incoming Mobilizon joins" do
      user = insert(:user)

      event = insert(:event)

      join_data =
        File.read!("test/fixtures/tesla_mock/mobilizon-event-join.json")
        |> Jason.decode!()
        |> Map.put("actor", user.ap_id)
        |> Map.put("object", event.data["id"])

      {:ok, %Activity{local: false} = activity} = Transmogrifier.handle_incoming(join_data)

      event = Object.get_by_id(event.id)

      assert event.data["participations"] == [join_data["actor"]]

      activity = Repo.get(Activity, activity.id)
      assert activity.data["state"] == "accept"
    end

    test "with restricted events, it does create a Join, but not an Accept" do
      [participant, event_author] = insert_pair(:user)

      event = insert(:event, %{user: event_author, data: %{"joinMode" => "restricted"}})

      join_data =
        File.read!("test/fixtures/tesla_mock/mobilizon-event-join.json")
        |> Jason.decode!()
        |> Map.put("actor", participant.ap_id)
        |> Map.put("object", event.data["id"])

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(join_data)

      event = Object.get_by_id(event.id)

      assert event.data["participations"] == nil

      assert data["state"] == "pending"

      accepts =
        from(
          a in Activity,
          where: fragment("?->>'type' = ?", a.data, "Accept")
        )
        |> Repo.all()

      assert Enum.empty?(accepts)

      [notification] = Notification.for_user(event_author)
      assert notification.type == "pleroma:participation_request"
    end
  end
end
