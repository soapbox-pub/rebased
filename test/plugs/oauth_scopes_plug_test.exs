# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.OAuthScopesPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.Repo

  import Mock
  import Pleroma.Factory

  setup_with_mocks([{EnsurePublicOrAuthenticatedPlug, [], [call: fn conn, _ -> conn end]}]) do
    :ok
  end

  test "if `token.scopes` fulfills specified 'any of' conditions, " <>
         "proceeds with no op",
       %{conn: conn} do
    token = insert(:oauth_token, scopes: ["read", "write"]) |> Repo.preload(:user)

    conn =
      conn
      |> assign(:user, token.user)
      |> assign(:token, token)
      |> OAuthScopesPlug.call(%{scopes: ["read"]})

    refute conn.halted
    assert conn.assigns[:user]
  end

  test "if `token.scopes` fulfills specified 'all of' conditions, " <>
         "proceeds with no op",
       %{conn: conn} do
    token = insert(:oauth_token, scopes: ["scope1", "scope2", "scope3"]) |> Repo.preload(:user)

    conn =
      conn
      |> assign(:user, token.user)
      |> assign(:token, token)
      |> OAuthScopesPlug.call(%{scopes: ["scope2", "scope3"], op: :&})

    refute conn.halted
    assert conn.assigns[:user]
  end

  describe "with `fallback: :proceed_unauthenticated` option, " do
    test "if `token.scopes` doesn't fulfill specified conditions, " <>
           "clears :user and :token assigns and calls EnsurePublicOrAuthenticatedPlug",
         %{conn: conn} do
      user = insert(:user)
      token1 = insert(:oauth_token, scopes: ["read", "write"], user: user)

      for token <- [token1, nil], op <- [:|, :&] do
        ret_conn =
          conn
          |> assign(:user, user)
          |> assign(:token, token)
          |> OAuthScopesPlug.call(%{
            scopes: ["follow"],
            op: op,
            fallback: :proceed_unauthenticated
          })

        refute ret_conn.halted
        refute ret_conn.assigns[:user]
        refute ret_conn.assigns[:token]

        assert called(EnsurePublicOrAuthenticatedPlug.call(ret_conn, :_))
      end
    end

    test "with :skip_instance_privacy_check option, " <>
           "if `token.scopes` doesn't fulfill specified conditions, " <>
           "clears :user and :token assigns and does NOT call EnsurePublicOrAuthenticatedPlug",
         %{conn: conn} do
      user = insert(:user)
      token1 = insert(:oauth_token, scopes: ["read:statuses", "write"], user: user)

      for token <- [token1, nil], op <- [:|, :&] do
        ret_conn =
          conn
          |> assign(:user, user)
          |> assign(:token, token)
          |> OAuthScopesPlug.call(%{
            scopes: ["read"],
            op: op,
            fallback: :proceed_unauthenticated,
            skip_instance_privacy_check: true
          })

        refute ret_conn.halted
        refute ret_conn.assigns[:user]
        refute ret_conn.assigns[:token]

        refute called(EnsurePublicOrAuthenticatedPlug.call(ret_conn, :_))
      end
    end
  end

  describe "without :fallback option, " do
    test "if `token.scopes` does not fulfill specified 'any of' conditions, " <>
           "returns 403 and halts",
         %{conn: conn} do
      for token <- [insert(:oauth_token, scopes: ["read", "write"]), nil] do
        any_of_scopes = ["follow", "push"]

        ret_conn =
          conn
          |> assign(:token, token)
          |> OAuthScopesPlug.call(%{scopes: any_of_scopes})

        assert ret_conn.halted
        assert 403 == ret_conn.status

        expected_error = "Insufficient permissions: #{Enum.join(any_of_scopes, " | ")}."
        assert Jason.encode!(%{error: expected_error}) == ret_conn.resp_body
      end
    end

    test "if `token.scopes` does not fulfill specified 'all of' conditions, " <>
           "returns 403 and halts",
         %{conn: conn} do
      for token <- [insert(:oauth_token, scopes: ["read", "write"]), nil] do
        token_scopes = (token && token.scopes) || []
        all_of_scopes = ["write", "follow"]

        conn =
          conn
          |> assign(:token, token)
          |> OAuthScopesPlug.call(%{scopes: all_of_scopes, op: :&})

        assert conn.halted
        assert 403 == conn.status

        expected_error =
          "Insufficient permissions: #{Enum.join(all_of_scopes -- token_scopes, " & ")}."

        assert Jason.encode!(%{error: expected_error}) == conn.resp_body
      end
    end
  end

  describe "with hierarchical scopes, " do
    test "if `token.scopes` fulfills specified 'any of' conditions, " <>
           "proceeds with no op",
         %{conn: conn} do
      token = insert(:oauth_token, scopes: ["read", "write"]) |> Repo.preload(:user)

      conn =
        conn
        |> assign(:user, token.user)
        |> assign(:token, token)
        |> OAuthScopesPlug.call(%{scopes: ["read:something"]})

      refute conn.halted
      assert conn.assigns[:user]
    end

    test "if `token.scopes` fulfills specified 'all of' conditions, " <>
           "proceeds with no op",
         %{conn: conn} do
      token = insert(:oauth_token, scopes: ["scope1", "scope2", "scope3"]) |> Repo.preload(:user)

      conn =
        conn
        |> assign(:user, token.user)
        |> assign(:token, token)
        |> OAuthScopesPlug.call(%{scopes: ["scope1:subscope", "scope2:subscope"], op: :&})

      refute conn.halted
      assert conn.assigns[:user]
    end
  end

  describe "filter_descendants/2" do
    test "filters scopes which directly match or are ancestors of supported scopes" do
      f = fn scopes, supported_scopes ->
        OAuthScopesPlug.filter_descendants(scopes, supported_scopes)
      end

      assert f.(["read", "follow"], ["write", "read"]) == ["read"]

      assert f.(["read", "write:something", "follow"], ["write", "read"]) ==
               ["read", "write:something"]

      assert f.(["admin:read"], ["write", "read"]) == []

      assert f.(["admin:read"], ["write", "admin"]) == ["admin:read"]
    end
  end

  describe "transform_scopes/2" do
    clear_config([:auth, :enforce_oauth_admin_scope_usage])

    setup do
      {:ok, %{f: &OAuthScopesPlug.transform_scopes/2}}
    end

    test "with :admin option, prefixes all requested scopes with `admin:` " <>
           "and [optionally] keeps only prefixed scopes, " <>
           "depending on `[:auth, :enforce_oauth_admin_scope_usage]` setting",
         %{f: f} do
      Pleroma.Config.put([:auth, :enforce_oauth_admin_scope_usage], false)

      assert f.(["read"], %{admin: true}) == ["admin:read", "read"]

      assert f.(["read", "write"], %{admin: true}) == [
               "admin:read",
               "read",
               "admin:write",
               "write"
             ]

      Pleroma.Config.put([:auth, :enforce_oauth_admin_scope_usage], true)

      assert f.(["read:accounts"], %{admin: true}) == ["admin:read:accounts"]

      assert f.(["read", "write:reports"], %{admin: true}) == [
               "admin:read",
               "admin:write:reports"
             ]
    end

    test "with no supported options, returns unmodified scopes", %{f: f} do
      assert f.(["read"], %{}) == ["read"]
      assert f.(["read", "write"], %{}) == ["read", "write"]
    end
  end
end
