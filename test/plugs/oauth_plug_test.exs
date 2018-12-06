defmodule Pleroma.Plugs.OAuthPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Plugs.OAuthPlug
  import Pleroma.Factory

  @session_opts [
    store: :cookie,
    key: "_test",
    signing_salt: "cooldude"
  ]

  setup %{conn: conn} do
    user = insert(:user)
    {:ok, %{token: token}} = Pleroma.Web.OAuth.Token.create_token(insert(:oauth_app), user)
    %{user: user, token: token, conn: conn}
  end

  test "with valid token(uppercase), it assigns the user", %{conn: conn} = opts do
    conn =
      conn
      |> put_req_header("authorization", "BEARER #{opts[:token]}")
      |> OAuthPlug.call(%{})

    assert conn.assigns[:user] == opts[:user]
  end

  test "with valid token(downcase), it assigns the user", %{conn: conn} = opts do
    conn =
      conn
      |> put_req_header("authorization", "bearer #{opts[:token]}")
      |> OAuthPlug.call(%{})

    assert conn.assigns[:user] == opts[:user]
  end

  test "with invalid token, it not assigns the user", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "bearer TTTTT")
      |> OAuthPlug.call(%{})

    refute conn.assigns[:user]
  end

  test "when token is missed but token in session, it assigns the user", %{conn: conn} = opts do
    conn =
      conn
      |> Plug.Session.call(Plug.Session.init(@session_opts))
      |> fetch_session()
      |> put_session(:oauth_token, opts[:token])
      |> OAuthPlug.call(%{})

    assert conn.assigns[:user] == opts[:user]
  end
end
