defmodule Pleroma.Web.ActivityPub.ActivityPubControllerTest do
  use Pleroma.Web.ConnCase
  import Pleroma.Factory
  alias Pleroma.Web.ActivityPub.{UserView, ObjectView}
  alias Pleroma.{Repo, User}
  alias Pleroma.Activity

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "/relay" do
    test "with the relay active, it returns the relay user", %{conn: conn} do
      res =
        conn
        |> get(activity_pub_path(conn, :relay))
        |> json_response(200)

      assert res["id"] =~ "/relay"
    end

    test "with the relay disabled, it returns 404", %{conn: conn} do
      Pleroma.Config.put([:instance, :allow_relay], false)

      conn
      |> get(activity_pub_path(conn, :relay))
      |> json_response(404)
      |> assert

      Pleroma.Config.put([:instance, :allow_relay], true)
    end
  end

  describe "/users/:nickname" do
    test "it returns a json representation of the user", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/users/#{user.nickname}")

      user = Repo.get(User, user.id)

      assert json_response(conn, 200) == UserView.render("user.json", %{user: user})
    end
  end

  describe "/object/:uuid" do
    test "it returns a json representation of the object", %{conn: conn} do
      note = insert(:note)
      uuid = String.split(note.data["id"], "/") |> List.last()

      conn =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/objects/#{uuid}")

      assert json_response(conn, 200) == ObjectView.render("object.json", %{object: note})
    end

    test "it returns 404 for non-public messages", %{conn: conn} do
      note = insert(:direct_note)
      uuid = String.split(note.data["id"], "/") |> List.last()

      conn =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/objects/#{uuid}")

      assert json_response(conn, 404)
    end
  end

  describe "/inbox" do
    test "it inserts an incoming activity into the database", %{conn: conn} do
      data = File.read!("test/fixtures/mastodon-post-activity.json") |> Poison.decode!()

      conn =
        conn
        |> assign(:valid_signature, true)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/inbox", data)

      assert "ok" == json_response(conn, 200)
      :timer.sleep(500)
      assert Activity.get_by_ap_id(data["id"])
    end
  end

  describe "/users/:nickname/inbox" do
    test "it inserts an incoming activity into the database", %{conn: conn} do
      user = insert(:user)

      data =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()
        |> Map.put("bcc", [user.ap_id])

      conn =
        conn
        |> assign(:valid_signature, true)
        |> put_req_header("content-type", "application/activity+json")
        |> post("/users/#{user.nickname}/inbox", data)

      assert "ok" == json_response(conn, 200)
      :timer.sleep(500)
      assert Activity.get_by_ap_id(data["id"])
    end
  end

  describe "/users/:nickname/outbox" do
    test "it returns a note activity in a collection", %{conn: conn} do
      note_activity = insert(:note_activity)
      user = User.get_cached_by_ap_id(note_activity.data["actor"])

      conn =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/users/#{user.nickname}/outbox")

      assert response(conn, 200) =~ note_activity.data["object"]["content"]
    end

    test "it returns an announce activity in a collection", %{conn: conn} do
      announce_activity = insert(:announce_activity)
      user = User.get_cached_by_ap_id(announce_activity.data["actor"])

      conn =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/users/#{user.nickname}/outbox")

      assert response(conn, 200) =~ announce_activity.data["object"]
    end
  end

  describe "/users/:nickname/followers" do
    test "it returns the followers in a collection", %{conn: conn} do
      user = insert(:user)
      user_two = insert(:user)
      User.follow(user, user_two)

      result =
        conn
        |> get("/users/#{user_two.nickname}/followers")
        |> json_response(200)

      assert result["first"]["orderedItems"] == [user.ap_id]
    end

    test "it returns returns empty if the user has 'hide_network' set", %{conn: conn} do
      user = insert(:user)
      user_two = insert(:user, %{info: %{hide_network: true}})
      User.follow(user, user_two)

      result =
        conn
        |> get("/users/#{user_two.nickname}/followers")
        |> json_response(200)

      assert result["first"]["orderedItems"] == []
      assert result["totalItems"] == 1
    end

    test "it works for more than 10 users", %{conn: conn} do
      user = insert(:user)

      Enum.each(1..15, fn _ ->
        other_user = insert(:user)
        User.follow(other_user, user)
      end)

      result =
        conn
        |> get("/users/#{user.nickname}/followers")
        |> json_response(200)

      assert length(result["first"]["orderedItems"]) == 10
      assert result["first"]["totalItems"] == 15
      assert result["totalItems"] == 15

      result =
        conn
        |> get("/users/#{user.nickname}/followers?page=2")
        |> json_response(200)

      assert length(result["orderedItems"]) == 5
      assert result["totalItems"] == 15
    end
  end

  describe "/users/:nickname/following" do
    test "it returns the following in a collection", %{conn: conn} do
      user = insert(:user)
      user_two = insert(:user)
      User.follow(user, user_two)

      result =
        conn
        |> get("/users/#{user.nickname}/following")
        |> json_response(200)

      assert result["first"]["orderedItems"] == [user_two.ap_id]
    end

    test "it returns returns empty if the user has 'hide_network' set", %{conn: conn} do
      user = insert(:user, %{info: %{hide_network: true}})
      user_two = insert(:user)
      User.follow(user, user_two)

      result =
        conn
        |> get("/users/#{user.nickname}/following")
        |> json_response(200)

      assert result["first"]["orderedItems"] == []
      assert result["totalItems"] == 1
    end

    test "it works for more than 10 users", %{conn: conn} do
      user = insert(:user)

      Enum.each(1..15, fn _ ->
        user = Repo.get(User, user.id)
        other_user = insert(:user)
        User.follow(user, other_user)
      end)

      result =
        conn
        |> get("/users/#{user.nickname}/following")
        |> json_response(200)

      assert length(result["first"]["orderedItems"]) == 10
      assert result["first"]["totalItems"] == 15
      assert result["totalItems"] == 15

      result =
        conn
        |> get("/users/#{user.nickname}/following?page=2")
        |> json_response(200)

      assert length(result["orderedItems"]) == 5
      assert result["totalItems"] == 15
    end
  end
end
