defmodule Pleroma.Web.OStatus.DeleteHandlingTest do
  use Pleroma.DataCase

  import Pleroma.Factory
  import Tesla.Mock

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Web.OStatus

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "deletions" do
    test "it removes the mentioned activity" do
      note = insert(:note_activity)
      second_note = insert(:note_activity)
      user = insert(:user)
      object = Object.get_by_ap_id(note.data["object"]["id"])

      {:ok, like, _object} = Pleroma.Web.ActivityPub.ActivityPub.like(user, object)

      incoming =
        File.read!("test/fixtures/delete.xml")
        |> String.replace(
          "tag:mastodon.sdf.org,2017-06-10:objectId=310513:objectType=Status",
          note.data["object"]["id"]
        )

      {:ok, [delete]} = OStatus.handle_incoming(incoming)

      refute Activity.get_by_id(note.id)
      refute Activity.get_by_id(like.id)
      assert Object.get_by_ap_id(note.data["object"]["id"]).data["type"] == "Tombstone"
      assert Activity.get_by_id(second_note.id)
      assert Object.get_by_ap_id(second_note.data["object"]["id"])

      assert delete.data["type"] == "Delete"
    end
  end
end
