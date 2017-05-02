defmodule Pleroma.Web.OStatusTest do
  use Pleroma.DataCase
  alias Pleroma.Web.OStatus

  test "don't insert create notes twice" do
    incoming = File.read!("test/fixtures/incoming_note_activity.xml")
    {:ok, [_activity]} = OStatus.handle_incoming(incoming)
    assert {:ok, [{:error, "duplicate activity"}]} == OStatus.handle_incoming(incoming)
  end

  test "handle incoming note - GS, Salmon" do
    incoming = File.read!("test/fixtures/incoming_note_activity.xml")
    {:ok, [activity]} = OStatus.handle_incoming(incoming)

    assert activity.data["type"] == "Create"
    assert activity.data["object"]["type"] == "Note"
    assert activity.data["object"]["id"] == "tag:gs.example.org:4040,2017-04-23:noticeId=29:objectType=note"
    assert activity.data["published"] == "2017-04-23T14:51:03+00:00"
    assert activity.data["context"] == "tag:gs.example.org:4040,2017-04-23:objectType=thread:nonce=f09e22f58abd5c7b"
    assert "http://pleroma.example.org:4000/users/lain3" in activity.data["to"]
    assert activity.local == false
  end

  test "handle incoming notes - GS, subscription" do
    incoming = File.read!("test/fixtures/ostatus_incoming_post.xml")
    {:ok, [activity]} = OStatus.handle_incoming(incoming)

    assert activity.data["type"] == "Create"
    assert activity.data["object"]["type"] == "Note"
    assert activity.data["object"]["actor"] == "https://social.heldscal.la/user/23211"
    assert activity.data["object"]["content"] == "Will it blend?"
  end

  test "handle incoming notes - GS, subscription, reply" do
    incoming = File.read!("test/fixtures/ostatus_incoming_reply.xml")
    {:ok, [activity]} = OStatus.handle_incoming(incoming)

    assert activity.data["type"] == "Create"
    assert activity.data["object"]["type"] == "Note"
    assert activity.data["object"]["actor"] == "https://social.heldscal.la/user/23211"
    assert activity.data["object"]["content"] == "@<a href=\"https://gs.archae.me/user/4687\" class=\"h-card u-url p-nickname mention\" title=\"shpbot\">shpbot</a> why not indeed."
    assert activity.data["object"]["inReplyTo"] == "tag:gs.archae.me,2017-04-30:noticeId=778260:objectType=note"
  end

  test "handle incoming replies" do
    incoming = File.read!("test/fixtures/incoming_note_activity_answer.xml")
    {:ok, [activity]} = OStatus.handle_incoming(incoming)

    assert activity.data["type"] == "Create"
    assert activity.data["object"]["type"] == "Note"
    assert activity.data["object"]["inReplyTo"] == "http://pleroma.example.org:4000/objects/55bce8fc-b423-46b1-af71-3759ab4670bc"
    assert "http://pleroma.example.org:4000/users/lain5" in activity.data["to"]
  end

  describe "new remote user creation" do
    test "tries to use the information in poco fields" do
      # TODO make test local
      uri = "https://social.heldscal.la/user/23211"

      {:ok, user} = OStatus.find_or_make_user(uri)

      user = Repo.get(Pleroma.User, user.id)
      assert user.name == "Constance Variable"
      assert user.nickname == "lambadalambda@social.heldscal.la"
      assert user.local == false
      assert user.info["uri"] == uri
      assert user.ap_id == uri
      assert user.avatar["type"] == "Image"

      {:ok, user_again} = OStatus.find_or_make_user(uri)

      assert user == user_again
    end
  end

  describe "gathering user info from a user id" do
    test "it returns user info in a hash" do
      user = "shp@social.heldscal.la"

      # TODO: make test local
      {:ok, data} = OStatus.gather_user_info(user)

      expected = %{
        hub: "https://social.heldscal.la/main/push/hub",
        magic_key: "RSA.wQ3i9UA0qmAxZ0WTIp4a-waZn_17Ez1pEEmqmqoooRsG1_BvpmOvLN0G2tEcWWxl2KOtdQMCiPptmQObeZeuj48mdsDZ4ArQinexY2hCCTcbV8Xpswpkb8K05RcKipdg07pnI7tAgQ0VWSZDImncL6YUGlG5YN8b5TjGOwk2VG8=.AQAB",
        name: "shp",
        nickname: "shp",
        salmon: "https://social.heldscal.la/main/salmon/user/29191",
        subject: "acct:shp@social.heldscal.la",
        topic: "https://social.heldscal.la/api/statuses/user_timeline/29191.atom",
        uri: "https://social.heldscal.la/user/29191",
        host: "social.heldscal.la",
        fqn: user,
        avatar: %{"type" => "Image", "url" => [%{"href" => "https://social.heldscal.la/avatar/29191-original-20170421154949.jpeg", "mediaType" => "image/jpeg", "type" => "Link"}]}
      }
      assert data == expected
    end

    test "it works with the uri" do
      user = "https://social.heldscal.la/user/29191"

      # TODO: make test local
      {:ok, data} = OStatus.gather_user_info(user)

      expected = %{
        hub: "https://social.heldscal.la/main/push/hub",
        magic_key: "RSA.wQ3i9UA0qmAxZ0WTIp4a-waZn_17Ez1pEEmqmqoooRsG1_BvpmOvLN0G2tEcWWxl2KOtdQMCiPptmQObeZeuj48mdsDZ4ArQinexY2hCCTcbV8Xpswpkb8K05RcKipdg07pnI7tAgQ0VWSZDImncL6YUGlG5YN8b5TjGOwk2VG8=.AQAB",
        name: "shp",
        nickname: "shp",
        salmon: "https://social.heldscal.la/main/salmon/user/29191",
        subject: "https://social.heldscal.la/user/29191",
        topic: "https://social.heldscal.la/api/statuses/user_timeline/29191.atom",
        uri: "https://social.heldscal.la/user/29191",
        host: "social.heldscal.la",
        fqn: user,
        avatar: %{"type" => "Image", "url" => [%{"href" => "https://social.heldscal.la/avatar/29191-original-20170421154949.jpeg", "mediaType" => "image/jpeg", "type" => "Link"}]}
      }
      assert data == expected
    end
  end
end
