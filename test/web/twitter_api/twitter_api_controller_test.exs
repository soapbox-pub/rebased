defmodule Pleroma.Web.TwitterAPI.ControllerTest do
  use Pleroma.Web.ConnCase
  alias Pleroma.Web.TwitterAPI.Representers.{UserRepresenter, ActivityRepresenter}
  alias Pleroma.Builders.{ActivityBuilder, UserBuilder}
  alias Pleroma.{Repo, Activity, User}

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

  describe "GET /statuses/friends_timeline.json" do
    setup [:valid_user]
    test "without valid credentials", %{conn: conn} do
      conn = get conn, "/api/statuses/friends_timeline.json"
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials", %{conn: conn, user: current_user} do
      {:ok, user} = UserBuilder.insert
      activities = ActivityBuilder.insert_list(30, %{"to" => [User.ap_followers(user)]}, %{user: user})
      ActivityBuilder.insert_list(10, %{"to" => [User.ap_followers(user)]}, %{user: user})
      {:ok, other_user} = UserBuilder.insert(%{ap_id: "glimmung", nickname: "nockame"})
      ActivityBuilder.insert_list(10, %{}, %{user: other_user})
      since_id = List.last(activities).id

      current_user = Ecto.Changeset.change(current_user, following: [User.ap_followers(user)]) |> Repo.update!

      conn = conn
        |> with_credentials(current_user.nickname, "test")
        |> get("/api/statuses/friends_timeline.json", %{since_id: since_id})

      response = json_response(conn, 200)

      assert length(response) == 10
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
end
