defmodule Pleroma.Web.ActivityPub.TransmogrifierTest do
  use Pleroma.DataCase
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Activity
  import Pleroma.Factory
  alias Pleroma.Web.CommonAPI

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

  describe "prepare outgoing" do
    test "it turns mentions into tags" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "hey, @#{other_user.nickname}, how are ya?"})

      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)
      object = modified["object"]

      expected_tag = %{
        "href" => other_user.ap_id,
        "name" => "@#{other_user.nickname}",
        "type" => "Mention"
      }

      assert Enum.member?(object["tag"], expected_tag)
    end

    test "it adds the json-ld context" do
      user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "hey"})
      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

      assert modified["@context"] == "https://www.w3.org/ns/activitystreams"
    end

    test "it sets the 'attributedTo' property to the actor of the object if it doesn't have one" do
      user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "hey"})
      {:ok, modified} = Transmogrifier.prepare_outgoing(activity.data)

      assert modified["object"]["actor"] == modified["object"]["attributedTo"]
    end
  end
end
