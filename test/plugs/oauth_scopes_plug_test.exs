# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.OAuthScopesPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.Repo

  import Pleroma.Factory

  test "proceeds with no op if `assigns[:token]` is nil", %{conn: conn} do
    conn =
      conn
      |> assign(:user, insert(:user))
      |> OAuthScopesPlug.call(%{scopes: ["read"]})

    refute conn.halted
    assert conn.assigns[:user]
  end

  test "proceeds with no op if `token.scopes` fulfill specified 'any of' conditions", %{
    conn: conn
  } do
    token = insert(:oauth_token, scopes: ["read", "write"]) |> Repo.preload(:user)

    conn =
      conn
      |> assign(:user, token.user)
      |> assign(:token, token)
      |> OAuthScopesPlug.call(%{scopes: ["read"]})

    refute conn.halted
    assert conn.assigns[:user]
  end

  test "proceeds with no op if `token.scopes` fulfill specified 'all of' conditions", %{
    conn: conn
  } do
    token = insert(:oauth_token, scopes: ["scope1", "scope2", "scope3"]) |> Repo.preload(:user)

    conn =
      conn
      |> assign(:user, token.user)
      |> assign(:token, token)
      |> OAuthScopesPlug.call(%{scopes: ["scope2", "scope3"], op: :&})

    refute conn.halted
    assert conn.assigns[:user]
  end

  test "proceeds with cleared `assigns[:user]` if `token.scopes` doesn't fulfill specified 'any of' conditions " <>
         "and `fallback: :proceed_unauthenticated` option is specified",
       %{conn: conn} do
    token = insert(:oauth_token, scopes: ["read", "write"]) |> Repo.preload(:user)

    conn =
      conn
      |> assign(:user, token.user)
      |> assign(:token, token)
      |> OAuthScopesPlug.call(%{scopes: ["follow"], fallback: :proceed_unauthenticated})

    refute conn.halted
    refute conn.assigns[:user]
  end

  test "proceeds with cleared `assigns[:user]` if `token.scopes` doesn't fulfill specified 'all of' conditions " <>
         "and `fallback: :proceed_unauthenticated` option is specified",
       %{conn: conn} do
    token = insert(:oauth_token, scopes: ["read", "write"]) |> Repo.preload(:user)

    conn =
      conn
      |> assign(:user, token.user)
      |> assign(:token, token)
      |> OAuthScopesPlug.call(%{
        scopes: ["read", "follow"],
        op: :&,
        fallback: :proceed_unauthenticated
      })

    refute conn.halted
    refute conn.assigns[:user]
  end

  test "returns 403 and halts in case of no :fallback option and `token.scopes` not fulfilling specified 'any of' conditions",
       %{conn: conn} do
    token = insert(:oauth_token, scopes: ["read", "write"])
    any_of_scopes = ["follow"]

    conn =
      conn
      |> assign(:token, token)
      |> OAuthScopesPlug.call(%{scopes: any_of_scopes})

    assert conn.halted
    assert 403 == conn.status

    expected_error = "Insufficient permissions: #{Enum.join(any_of_scopes, ", ")}."
    assert Jason.encode!(%{error: expected_error}) == conn.resp_body
  end

  test "returns 403 and halts in case of no :fallback option and `token.scopes` not fulfilling specified 'all of' conditions",
       %{conn: conn} do
    token = insert(:oauth_token, scopes: ["read", "write"])
    all_of_scopes = ["write", "follow"]

    conn =
      conn
      |> assign(:token, token)
      |> OAuthScopesPlug.call(%{scopes: all_of_scopes, op: :&})

    assert conn.halted
    assert 403 == conn.status

    expected_error =
      "Insufficient permissions: #{Enum.join(all_of_scopes -- token.scopes, ", ")}."

    assert Jason.encode!(%{error: expected_error}) == conn.resp_body
  end
end
