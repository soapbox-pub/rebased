defmodule Pleroma.Plugs.AuthenticationPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Plugs.AuthenticationPlug

  defp fetch_nil(_name) do
    {:ok, nil}
  end

  @user %{
    id: 1,
    name: "dude",
    password_hash: Comeonin.Pbkdf2.hashpwsalt("guy")
  }

  @session_opts [
    store: :cookie,
    key: "_test",
    signing_salt: "cooldude"
  ]

  defp fetch_user(_name) do
    {:ok, @user}
  end

  defp basic_auth_enc(username, password) do
    "Basic " <> Base.encode64("#{username}:#{password}")
  end

  describe "without an authorization header" do
    test "it halts the application" do
      conn = build_conn()
      |> Plug.Session.call(Plug.Session.init(@session_opts))
      |> fetch_session
      |> AuthenticationPlug.call(%{})

      assert conn.status == 403
      assert conn.halted == true
    end

    test "it assigns a nil user if the 'optional' option is used" do
      conn = build_conn()
      |> Plug.Session.call(Plug.Session.init(@session_opts))
      |> fetch_session
      |> AuthenticationPlug.call(%{optional: true})

      assert %{ user: nil } == conn.assigns
    end
  end

  describe "with an authorization header for a nonexisting user" do
    test "it halts the application" do
      conn =
        build_conn()
        |> Plug.Session.call(Plug.Session.init(@session_opts))
        |> fetch_session
        |> AuthenticationPlug.call(%{fetcher: &fetch_nil/1})

      assert conn.status == 403
      assert conn.halted == true
    end

    test "it assigns a nil user if the 'optional' option is used" do
      conn =
        build_conn()
        |> Plug.Session.call(Plug.Session.init(@session_opts))
        |> fetch_session
        |> AuthenticationPlug.call(%{optional: true, fetcher: &fetch_nil/1 })

      assert %{ user: nil } == conn.assigns
    end
  end

  describe "with an incorrect authorization header for a enxisting user" do
    test "it halts the application" do
      opts = %{
        fetcher: &fetch_user/1
      }

      header = basic_auth_enc("dude", "man")

      conn =
        build_conn()
        |> Plug.Session.call(Plug.Session.init(@session_opts))
        |> fetch_session
        |> put_req_header("authorization", header)
        |> AuthenticationPlug.call(opts)

      assert conn.status == 403
      assert conn.halted == true
    end

    test "it assigns a nil user if the 'optional' option is used" do
      opts = %{
        optional: true,
        fetcher: &fetch_user/1
      }

      header = basic_auth_enc("dude", "man")

      conn =
        build_conn()
        |> Plug.Session.call(Plug.Session.init(@session_opts))
        |> fetch_session
        |> put_req_header("authorization", header)
        |> AuthenticationPlug.call(opts)

      assert %{ user: nil } == conn.assigns
    end
  end

  describe "with a correct authorization header for an existing user" do
    test "it assigns the user", %{conn: conn} do
      opts = %{
        optional: true,
        fetcher: &fetch_user/1
      }

      header = basic_auth_enc("dude", "guy")

      conn = conn
        |> Plug.Session.call(Plug.Session.init(@session_opts))
        |> fetch_session
        |> put_req_header("authorization", header)
        |> AuthenticationPlug.call(opts)

      assert %{ user: @user } == conn.assigns
      assert get_session(conn, :user_id) == @user.id
      assert conn.halted == false
    end
  end
  describe "with a user_id in the session for an existing user" do
    test "it assigns the user", %{conn: conn} do
      opts = %{
        optional: true,
        fetcher: &fetch_user/1
      }

      header = basic_auth_enc("dude", "THIS IS WRONG")

      conn = conn
        |> Plug.Session.call(Plug.Session.init(@session_opts))
        |> fetch_session
        |> put_session(:user_id, @user.id)
        |> put_req_header("authorization", header)
        |> AuthenticationPlug.call(opts)

      assert %{ user: @user } == conn.assigns
      assert get_session(conn, :user_id) == @user.id
      assert conn.halted == false
    end
  end
end
