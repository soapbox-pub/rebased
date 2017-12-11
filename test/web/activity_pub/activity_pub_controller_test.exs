defmodule Pleroma.Web.ActivityPub.ActivityPubControllerTest do
  use Pleroma.Web.ConnCase
  import Pleroma.Factory
  alias Pleroma.Web.ActivityPub.{UserView, ObjectView}
  alias Pleroma.{Repo, User}

  describe "/users/:nickname" do
    test "it returns a json representation of the user", %{conn: conn} do
      user = insert(:user)

      conn = conn
      |> put_req_header("accept", "application/activity+json")
      |> get("/users/#{user.nickname}")

      user = Repo.get(User, user.id)

      assert json_response(conn, 200) == UserView.render("user.json", %{user: user})
    end
  end

  describe "/object/:uuid" do
    test "it returns a json representation of the object", %{conn: conn} do
      note = insert(:note)
      uuid = String.split(note.data["id"], "/") |> List.last

      conn = conn
      |> put_req_header("accept", "application/activity+json")
      |> get("/objects/#{uuid}")

      assert json_response(conn, 200) == ObjectView.render("object.json", %{object: note})
    end
  end

  describe "/users/:nickname/inbox" do
    test "it inserts an incoming activity into the database" do
      assert false
    end
  end
end
