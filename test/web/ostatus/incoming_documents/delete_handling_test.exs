defmodule Pleroma.Web.OStatus.DeleteHandlingTest do
  use Pleroma.DataCase

  import Pleroma.Factory
  alias Pleroma.{Repo, Activity, Object}
  alias Pleroma.Web.OStatus

  describe "deletions" do
    test "it removes the mentioned activity" do
      note = insert(:note_activity)
      second_note = insert(:note_activity)

      incoming = File.read!("test/fixtures/delete.xml")
      |> String.replace("tag:mastodon.sdf.org,2017-06-10:objectId=310513:objectType=Status", note.data["object"]["id"])
      {:ok, []} = OStatus.handle_incoming(incoming)

      refute Repo.get(Activity, note.id)
      refute Object.get_by_ap_id(note.data["object"]["id"])
      assert Repo.get(Activity, second_note.id)
      assert Object.get_by_ap_id(second_note.data["object"]["id"])
    end
  end
end
