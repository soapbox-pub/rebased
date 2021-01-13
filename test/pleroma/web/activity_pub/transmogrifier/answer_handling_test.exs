# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.AnswerHandlingTest do
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  test "incoming, rewrites Note to Answer and increments vote counters" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "suya...",
        poll: %{options: ["suya", "suya.", "suya.."], expires_in: 10}
      })

    object = Object.normalize(activity, fetch: false)
    assert object.data["repliesCount"] == nil

    data =
      File.read!("test/fixtures/mastodon-vote.json")
      |> Jason.decode!()
      |> Kernel.put_in(["to"], user.ap_id)
      |> Kernel.put_in(["object", "inReplyTo"], object.data["id"])
      |> Kernel.put_in(["object", "to"], user.ap_id)

    {:ok, %Activity{local: false} = activity} = Transmogrifier.handle_incoming(data)
    answer_object = Object.normalize(activity, fetch: false)
    assert answer_object.data["type"] == "Answer"
    assert answer_object.data["inReplyTo"] == object.data["id"]

    new_object = Object.get_by_ap_id(object.data["id"])
    assert new_object.data["repliesCount"] == nil

    assert Enum.any?(
             new_object.data["oneOf"],
             fn
               %{"name" => "suya..", "replies" => %{"totalItems" => 1}} -> true
               _ -> false
             end
           )
  end

  test "outgoing, rewrites Answer to Note" do
    user = insert(:user)

    {:ok, poll_activity} =
      CommonAPI.post(user, %{
        status: "suya...",
        poll: %{options: ["suya", "suya.", "suya.."], expires_in: 10}
      })

    poll_object = Object.normalize(poll_activity, fetch: false)
    # TODO: Replace with CommonAPI vote creation when implemented
    data =
      File.read!("test/fixtures/mastodon-vote.json")
      |> Jason.decode!()
      |> Kernel.put_in(["to"], user.ap_id)
      |> Kernel.put_in(["object", "inReplyTo"], poll_object.data["id"])
      |> Kernel.put_in(["object", "to"], user.ap_id)

    {:ok, %Activity{local: false} = activity} = Transmogrifier.handle_incoming(data)
    {:ok, data} = Transmogrifier.prepare_outgoing(activity.data)

    assert data["object"]["type"] == "Note"
  end
end
