defmodule Pleroma.Web.MastodonAPI.TagControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory
  import Tesla.Mock

  alias Pleroma.User

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "GET /api/v1/tags/:id" do
    test "returns 200 with tag" do
      %{user: user, conn: conn} = oauth_access(["read"])

      tag = insert(:hashtag, name: "jubjub")
      {:ok, _user} = User.follow_hashtag(user, tag)

      response =
        conn
        |> get("/api/v1/tags/jubjub")
        |> json_response_and_validate_schema(200)

      assert %{
               "name" => "jubjub",
               "url" => "http://localhost:4001/tags/jubjub",
               "history" => [],
               "following" => true
             } = response
    end

    test "returns 404 with unknown tag" do
      %{conn: conn} = oauth_access(["read"])

      conn
      |> get("/api/v1/tags/jubjub")
      |> json_response_and_validate_schema(404)
    end
  end

  describe "POST /api/v1/tags/:id/follow" do
    test "should follow a hashtag" do
      %{user: user, conn: conn} = oauth_access(["write:follows"])
      hashtag = insert(:hashtag, name: "jubjub")

      response =
        conn
        |> post("/api/v1/tags/jubjub/follow")
        |> json_response_and_validate_schema(200)

      assert response["following"] == true
      user = User.get_cached_by_ap_id(user.ap_id)
      assert User.following_hashtag?(user, hashtag)
    end

    test "should 404 if hashtag doesn't exist" do
      %{conn: conn} = oauth_access(["write:follows"])

      response =
        conn
        |> post("/api/v1/tags/rubrub/follow")
        |> json_response_and_validate_schema(404)

      assert response["error"] == "Hashtag not found"
    end
  end

  describe "POST /api/v1/tags/:id/unfollow" do
    test "should unfollow a hashtag" do
      %{user: user, conn: conn} = oauth_access(["write:follows"])
      hashtag = insert(:hashtag, name: "jubjub")
      {:ok, user} = User.follow_hashtag(user, hashtag)

      response =
        conn
        |> post("/api/v1/tags/jubjub/unfollow")
        |> json_response_and_validate_schema(200)

      assert response["following"] == false
      user = User.get_cached_by_ap_id(user.ap_id)
      refute User.following_hashtag?(user, hashtag)
    end

    test "should 404 if hashtag doesn't exist" do
      %{conn: conn} = oauth_access(["write:follows"])

      response =
        conn
        |> post("/api/v1/tags/rubrub/unfollow")
        |> json_response_and_validate_schema(404)

      assert response["error"] == "Hashtag not found"
    end
  end
end
