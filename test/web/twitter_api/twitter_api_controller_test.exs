defmodule Pleroma.Web.TwitterAPI.ControllerTest do
  use Pleroma.Web.ConnCase
  alias Pleroma.Web.TwitterAPI.Representers.{UserRepresenter, ActivityRepresenter}
  alias Pleroma.Builders.{ActivityBuilder, UserBuilder}
  alias Pleroma.{Repo, Activity, User, Object}
  alias Pleroma.Web.ActivityPub.ActivityPub

  import Pleroma.Factory

  describe "POST /api/account/verify_credentials" do
    setup [:valid_user]
    test "without valid credentials", %{conn: conn} do
      conn = post conn, "/api/account/verify_credentials.json"
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: user} do
      conn = conn
        |> with_credentials(user.nickname, "test")
        |> post("/api/account/verify_credentials.json")

      assert json_response(conn, 200) == UserRepresenter.to_map(user)
    end
  end

  describe "POST /statuses/update.json" do
    setup [:valid_user]
    test "without valid credentials", %{conn: conn} do
      conn = post conn, "/api/statuses/update.json"
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: user} do
      conn = conn
        |> with_credentials(user.nickname, "test")
        |> post("/api/statuses/update.json", %{ status: "Nice meme." })

      assert json_response(conn, 200) == ActivityRepresenter.to_map(Repo.one(Activity), %{user: user})
    end
  end

  describe "GET /statuses/public_timeline.json" do
    test "returns statuses", %{conn: conn} do
      {:ok, user} = UserBuilder.insert
      activities = ActivityBuilder.insert_list(30, %{}, %{user: user})
      ActivityBuilder.insert_list(10, %{}, %{user: user})
      since_id = List.last(activities).id

      conn = conn
        |> get("/api/statuses/public_timeline.json", %{since_id: since_id})

      response = json_response(conn, 200)

      assert length(response) == 10
    end
  end

  describe "GET /statuses/show/:id.json" do
    test "returns one status", %{conn: conn} do
      {:ok, user} = UserBuilder.insert
      {:ok, activity} = ActivityBuilder.insert(%{}, %{user: user})
      actor = Repo.get_by!(User, ap_id: activity.data["actor"])

      conn = conn
      |> get("/api/statuses/show/#{activity.id}.json")

      response = json_response(conn, 200)

      assert response == ActivityRepresenter.to_map(activity, %{user: actor})
    end
  end

  describe "GET /statusnet/conversation/:id.json" do
    test "returns the statuses in the conversation", %{conn: conn} do
      {:ok, _user} = UserBuilder.insert
      {:ok, _activity} = ActivityBuilder.insert(%{"statusnetConversationId" => 1, "context" => "2hu"})
      {:ok, _activity_two} = ActivityBuilder.insert(%{"statusnetConversationId" => 1,"context" => "2hu"})
      {:ok, _activity_three} = ActivityBuilder.insert(%{"context" => "3hu"})

      conn = conn
      |> get("/api/statusnet/conversation/1.json")

      response = json_response(conn, 200)

      assert length(response) == 2
    end
  end

  describe "GET /statuses/friends_timeline.json" do
    setup [:valid_user]
    test "without valid credentials", %{conn: conn} do
      conn = get conn, "/api/statuses/friends_timeline.json"
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: current_user} do
      {:ok, user} = UserBuilder.insert
      activities = ActivityBuilder.insert_list(30, %{"to" => [User.ap_followers(user)]}, %{user: user})
      returned_activities = ActivityBuilder.insert_list(10, %{"to" => [User.ap_followers(user)]}, %{user: user})
      {:ok, other_user} = UserBuilder.insert(%{ap_id: "glimmung", nickname: "nockame"})
      ActivityBuilder.insert_list(10, %{}, %{user: other_user})
      since_id = List.last(activities).id

      current_user = Ecto.Changeset.change(current_user, following: [User.ap_followers(user)]) |> Repo.update!

      conn = conn
        |> with_credentials(current_user.nickname, "test")
        |> get("/api/statuses/friends_timeline.json", %{since_id: since_id})

      response = json_response(conn, 200)

      assert length(response) == 10
      assert response == Enum.map(returned_activities, fn (activity) -> ActivityRepresenter.to_map(activity, %{user: user, for: current_user}) end)
    end
  end

  describe "POST /friendships/create.json" do
    setup [:valid_user]
    test "without valid credentials", %{conn: conn} do
      conn = post conn, "/api/friendships/create.json"
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: current_user} do
      {:ok, followed } = UserBuilder.insert(%{name: "some guy"})

      conn = conn
      |> with_credentials(current_user.nickname, "test")
      |> post("/api/friendships/create.json", %{user_id: followed.id})

      current_user = Repo.get(User, current_user.id)
      assert current_user.following == [User.ap_followers(followed)]
      assert json_response(conn, 200) == UserRepresenter.to_map(followed, %{for: current_user})
    end
  end

  describe "POST /friendships/destroy.json" do
    setup [:valid_user]
    test "without valid credentials", %{conn: conn} do
      conn = post conn, "/api/friendships/destroy.json"
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: current_user} do
      {:ok, followed } = UserBuilder.insert(%{name: "some guy"})

      {:ok, current_user} = User.follow(current_user, followed)
      assert current_user.following == [User.ap_followers(followed)]

      conn = conn
      |> with_credentials(current_user.nickname, "test")
      |> post("/api/friendships/destroy.json", %{user_id: followed.id})

      current_user = Repo.get(User, current_user.id)
      assert current_user.following == []
      assert json_response(conn, 200) == UserRepresenter.to_map(followed, %{for: current_user})
    end
  end

  describe "POST /api/favorites/create/:id" do
    setup [:valid_user]
    test "without valid credentials", %{conn: conn} do
      note_activity = insert(:note_activity)
      conn = post conn, "/api/favorites/create/#{note_activity.id}.json"
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: current_user} do
      note_activity = insert(:note_activity)

      conn = conn
      |> with_credentials(current_user.nickname, "test")
      |> post("/api/favorites/create/#{note_activity.id}.json")

      assert json_response(conn, 200)
    end
  end

  describe "POST /api/favorites/destroy/:id" do
    setup [:valid_user]
    test "without valid credentials", %{conn: conn} do
      note_activity = insert(:note_activity)
      conn = post conn, "/api/favorites/destroy/#{note_activity.id}.json"
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: current_user} do
      note_activity = insert(:note_activity)
      object = Object.get_by_ap_id(note_activity.data["object"]["id"])
      ActivityPub.like(current_user, object)

      conn = conn
      |> with_credentials(current_user.nickname, "test")
      |> post("/api/favorites/destroy/#{note_activity.id}.json")

      assert json_response(conn, 200)
    end
  end

  describe "POST /api/statuses/retweet/:id" do
    setup [:valid_user]
    test "without valid credentials", %{conn: conn} do
      note_activity = insert(:note_activity)
      conn = post conn, "/api/statuses/retweet/#{note_activity.id}.json"
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: current_user} do
      note_activity = insert(:note_activity)

      conn = conn
      |> with_credentials(current_user.nickname, "test")
      |> post("/api/statuses/retweet/#{note_activity.id}.json")

      assert json_response(conn, 200)
    end
  end

  describe "POST /api/account/register" do
    test "it creates a new user", %{conn: conn} do
      data = %{
        "nickname" => "lain",
        "email" => "lain@wired.jp",
        "fullname" => "lain iwakura",
        "bio" => "close the world.",
        "password" => "bear",
        "confirm" => "bear"
      }

      conn = conn
      |> post("/api/account/register", data)

      user = json_response(conn, 200)

      fetched_user = Repo.get_by(User, nickname: "lain")
      assert user == UserRepresenter.to_map(fetched_user)
    end

    test "it returns errors on a problem", %{conn: conn} do
      data = %{
        "email" => "lain@wired.jp",
        "fullname" => "lain iwakura",
        "bio" => "close the world.",
        "password" => "bear",
        "confirm" => "bear"
      }

      conn = conn
      |> post("/api/account/register", data)

      errors = json_response(conn, 400)

      assert is_binary(errors["error"])
    end
  end

  defp valid_user(_context) do
    { :ok, user } = UserBuilder.insert(%{nickname: "lambda", ap_id: "lambda"})
    [user: user]
  end

  defp with_credentials(conn, username, password) do
    header_content = "Basic " <> Base.encode64("#{username}:#{password}")
    put_req_header(conn, "authorization", header_content)
  end

  setup do
    Supervisor.terminate_child(Pleroma.Supervisor, ConCache)
    Supervisor.restart_child(Pleroma.Supervisor, ConCache)
    :ok
  end
end
