defmodule Pleroma.Web.MastodonAPI.MastodonAPIControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Pleroma.{Repo, User, Activity}
  alias Pleroma.Web.OStatus

  import Pleroma.Factory

  test "the home timeline", %{conn: conn} do
    user = insert(:user)
    following = insert(:user)

    {:ok, _activity} = TwitterAPI.create_status(following, %{"status" => "test"})

    conn = conn
    |> assign(:user, user)
    |> get("/api/v1/timelines/home")

    assert length(json_response(conn, 200)) == 0

    {:ok, user} = User.follow(user, following)

    conn = build_conn()
    |> assign(:user, user)
    |> get("/api/v1/timelines/home")

    assert [%{"content" => "test"}] = json_response(conn, 200)
  end

  test "the public timeline", %{conn: conn} do
    following = insert(:user)

    {:ok, _activity} = TwitterAPI.create_status(following, %{"status" => "test"})
    {:ok, [_activity]} = OStatus.fetch_activity_from_url("https://shitposter.club/notice/2827873")

    conn = conn
    |> get("/api/v1/timelines/public")

    assert length(json_response(conn, 200)) == 2

    conn = build_conn()
    |> get("/api/v1/timelines/public", %{"local" => "True"})

    assert [%{"content" => "test"}] = json_response(conn, 200)
  end

  test "posting a status", %{conn: conn} do
    user = insert(:user)

    conn = conn
    |> assign(:user, user)
    |> post("/api/v1/statuses", %{"status" => "cofe"})

    assert %{"content" => "cofe", "id" => id} = json_response(conn, 200)
    assert Repo.get(Activity, id)
  end

  test "replying to a status", %{conn: conn} do
    user = insert(:user)

    {:ok, replied_to} = TwitterAPI.create_status(user, %{"status" => "cofe"})

    conn = conn
    |> assign(:user, user)
    |> post("/api/v1/statuses", %{"status" => "xD", "in_reply_to_id" => replied_to.id})

    assert %{"content" => "xD", "id" => id} = json_response(conn, 200)

    activity = Repo.get(Activity, id)

    assert activity.data["context"] == replied_to.data["context"]
    assert activity.data["object"]["inReplyToStatusId"] == replied_to.id
  end

  test "verify_credentials", %{conn: conn} do
    user = insert(:user)

    conn = conn
    |> assign(:user, user)
    |> get("/api/v1/accounts/verify_credentials")

    assert %{"id" => id} = json_response(conn, 200)
    assert id == user.id
  end

  test "get a status", %{conn: conn} do
    activity = insert(:note_activity)

    conn = conn
    |> get("/api/v1/statuses/#{activity.id}")

    assert %{"id" => id} = json_response(conn, 200)
    assert id == activity.id
  end
end
