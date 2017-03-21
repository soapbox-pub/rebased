defmodule Pleroma.Web.TwitterAPI.ControllerTest do
  use Pleroma.Web.ConnCase
  alias Pleroma.Web.TwitterAPI.Representers.{UserRepresenter, ActivityRepresenter}
  alias Pleroma.Builders.UserBuilder
  alias Pleroma.{Repo, Activity}

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

  defp valid_user(_context) do
    { :ok, user } = UserBuilder.insert
    [user: user]
  end

  defp with_credentials(conn, username, password) do
    header_content = "Basic " <> Base.encode64("#{username}:#{password}")
    put_req_header(conn, "authorization", header_content)
  end
end
