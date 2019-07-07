# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Integration.MastodonWebsocketTest do
  use Pleroma.DataCase

  import Pleroma.Factory

  alias Pleroma.Integration.WebsocketClient
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.OAuth
  alias Pleroma.Web.Streamer

  @path Pleroma.Web.Endpoint.url()
        |> URI.parse()
        |> Map.put(:scheme, "ws")
        |> Map.put(:path, "/api/v1/streaming")
        |> URI.to_string()

  setup do
    GenServer.start(Streamer, %{}, name: Streamer)

    on_exit(fn ->
      if pid = Process.whereis(Streamer) do
        Process.exit(pid, :kill)
      end
    end)
  end

  def start_socket(qs \\ nil, headers \\ []) do
    path =
      case qs do
        nil -> @path
        qs -> @path <> qs
      end

    WebsocketClient.start_link(self(), path, headers)
  end

  test "refuses invalid requests" do
    assert {:error, {400, _}} = start_socket()
    assert {:error, {404, _}} = start_socket("?stream=ncjdk")
  end

  test "requires authentication and a valid token for protected streams" do
    assert {:error, {403, _}} = start_socket("?stream=user&access_token=aaaaaaaaaaaa")
    assert {:error, {403, _}} = start_socket("?stream=user")
  end

  test "allows public streams without authentication" do
    assert {:ok, _} = start_socket("?stream=public")
    assert {:ok, _} = start_socket("?stream=public:local")
    assert {:ok, _} = start_socket("?stream=hashtag&tag=lain")
  end

  test "receives well formatted events" do
    user = insert(:user)
    {:ok, _} = start_socket("?stream=public")
    {:ok, activity} = CommonAPI.post(user, %{"status" => "nice echo chamber"})

    assert_receive {:text, raw_json}, 1_000
    assert {:ok, json} = Jason.decode(raw_json)

    assert "update" == json["event"]
    assert json["payload"]
    assert {:ok, json} = Jason.decode(json["payload"])

    view_json =
      Pleroma.Web.MastodonAPI.StatusView.render("status.json", activity: activity, for: nil)
      |> Jason.encode!()
      |> Jason.decode!()

    assert json == view_json
  end

  describe "with a valid user token" do
    setup do
      {:ok, app} =
        Pleroma.Repo.insert(
          OAuth.App.register_changeset(%OAuth.App{}, %{
            client_name: "client",
            scopes: ["scope"],
            redirect_uris: "url"
          })
        )

      user = insert(:user)

      {:ok, auth} = OAuth.Authorization.create_authorization(app, user)

      {:ok, token} = OAuth.Token.exchange_token(app, auth)

      %{user: user, token: token}
    end

    test "accepts valid tokens", state do
      assert {:ok, _} = start_socket("?stream=user&access_token=#{state.token.token}")
    end

    test "accepts the 'user' stream", %{token: token} = _state do
      assert {:ok, _} = start_socket("?stream=user&access_token=#{token.token}")
      assert {:error, {403, "Forbidden"}} = start_socket("?stream=user")
    end

    test "accepts the 'user:notification' stream", %{token: token} = _state do
      assert {:ok, _} = start_socket("?stream=user:notification&access_token=#{token.token}")
      assert {:error, {403, "Forbidden"}} = start_socket("?stream=user:notification")
    end

    test "accepts valid token on Sec-WebSocket-Protocol header", %{token: token} do
      assert {:ok, _} = start_socket("?stream=user", [{"Sec-WebSocket-Protocol", token.token}])

      assert {:error, {403, "Forbidden"}} =
               start_socket("?stream=user", [{"Sec-WebSocket-Protocol", "I am a friend"}])
    end
  end
end
