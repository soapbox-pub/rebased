# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.TokenTest do
  use Pleroma.DataCase, async: true
  alias Pleroma.Repo
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Authorization
  alias Pleroma.Web.OAuth.Token

  import Pleroma.Factory

  test "exchanges a auth token for an access token, preserving `scopes`" do
    {:ok, app} =
      Repo.insert(
        App.register_changeset(%App{}, %{
          client_name: "client",
          scopes: ["read", "write"],
          redirect_uris: "url"
        })
      )

    user = insert(:user)

    {:ok, auth} = Authorization.create_authorization(app, user, ["read"])
    assert auth.scopes == ["read"]

    {:ok, token} = Token.exchange_token(app, auth)

    assert token.app_id == app.id
    assert token.user_id == user.id
    assert token.scopes == auth.scopes
    assert String.length(token.token) > 10
    assert String.length(token.refresh_token) > 10

    auth = Repo.get(Authorization, auth.id)
    {:error, "already used"} = Token.exchange_token(app, auth)
  end

  test "deletes all tokens of a user" do
    {:ok, app1} =
      Repo.insert(
        App.register_changeset(%App{}, %{
          client_name: "client1",
          scopes: ["scope"],
          redirect_uris: "url"
        })
      )

    {:ok, app2} =
      Repo.insert(
        App.register_changeset(%App{}, %{
          client_name: "client2",
          scopes: ["scope"],
          redirect_uris: "url"
        })
      )

    user = insert(:user)

    {:ok, auth1} = Authorization.create_authorization(app1, user)
    {:ok, auth2} = Authorization.create_authorization(app2, user)

    {:ok, _token1} = Token.exchange_token(app1, auth1)
    {:ok, _token2} = Token.exchange_token(app2, auth2)

    {tokens, _} = Token.delete_user_tokens(user)

    assert tokens == 2
  end
end
