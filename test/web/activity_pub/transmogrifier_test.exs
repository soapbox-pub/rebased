defmodule Pleroma.Web.ActivityPub.TransmogrifierTest do
  use Pleroma.DataCase
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Activity

  describe "handle_incoming" do
    test "it works for incoming notices" do
      data = File.read!("test/fixtures/mastodon-post-activity.json") |> Poison.decode!

      {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)
      assert data["id"] == "http://mastodon.example.org/users/admin/statuses/99512778738411822/activity"
      assert data["context"] == "tag:mastodon.example.org,2018-02-12:objectId=20:objectType=Conversation"
      assert data["to"] == ["https://www.w3.org/ns/activitystreams#Public"]
      assert data["cc"] == [
        "http://mastodon.example.org/users/admin/followers",
        "http://localtesting.pleroma.lol/users/lain"
      ]
      assert data["actor"] == "http://mastodon.example.org/users/admin"

      object = data["object"]
      assert object["id"] == "http://mastodon.example.org/users/admin/statuses/99512778738411822"

      assert object["to"] == ["https://www.w3.org/ns/activitystreams#Public"]
      assert object["cc"] == [
        "http://mastodon.example.org/users/admin/followers",
        "http://localtesting.pleroma.lol/users/lain"
      ]
      assert object["actor"] == "http://mastodon.example.org/users/admin"
      assert object["attributedTo"] == "http://mastodon.example.org/users/admin"
    end
  end
end
