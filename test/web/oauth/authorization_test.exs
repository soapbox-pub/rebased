# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.AuthorizationTest do
  use Pleroma.DataCase
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Authorization
  import Pleroma.Factory

  setup do
    {:ok, app} =
      Repo.insert(
        App.register_changeset(%App{}, %{
          client_name: "client",
          scopes: ["read", "write"],
          redirect_uris: "url"
        })
      )

    %{app: app}
  end

  test "create an authorization token for a valid app", %{app: app} do
    user = insert(:user)

    {:ok, auth1} = Authorization.create_authorization(app, user)
    assert auth1.scopes == app.scopes

    {:ok, auth2} = Authorization.create_authorization(app, user, ["read"])
    assert auth2.scopes == ["read"]

    for auth <- [auth1, auth2] do
      assert auth.user_id == user.id
      assert auth.app_id == app.id
      assert String.length(auth.token) > 10
      assert auth.used == false
    end
  end

  test "use up a token", %{app: app} do
    user = insert(:user)

    {:ok, auth} = Authorization.create_authorization(app, user)

    {:ok, auth} = Authorization.use_token(auth)

    assert auth.used == true

    assert {:error, "already used"} == Authorization.use_token(auth)

    expired_auth = %Authorization{
      user_id: user.id,
      app_id: app.id,
      valid_until: NaiveDateTime.add(NaiveDateTime.utc_now(), -10),
      token: "mytoken",
      used: false
    }

    {:ok, expired_auth} = Repo.insert(expired_auth)

    assert {:error, "token expired"} == Authorization.use_token(expired_auth)
  end

  test "delete authorizations", %{app: app} do
    user = insert(:user)

    {:ok, auth} = Authorization.create_authorization(app, user)
    {:ok, auth} = Authorization.use_token(auth)

    Authorization.delete_user_authorizations(user)

    {_, invalid} = Authorization.use_token(auth)

    assert auth != invalid
  end
end
