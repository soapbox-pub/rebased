# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.AuthorizationTest do
  use Pleroma.DataCase
  alias Pleroma.Web.OAuth.{Authorization, App}
  import Pleroma.Factory

  test "create an authorization token for a valid app" do
    {:ok, app} =
      Repo.insert(
        App.register_changeset(%App{}, %{
          client_name: "client",
          scopes: "scope",
          redirect_uris: "url"
        })
      )

    user = insert(:user)

    {:ok, auth} = Authorization.create_authorization(app, user)

    assert auth.user_id == user.id
    assert auth.app_id == app.id
    assert String.length(auth.token) > 10
    assert auth.used == false
  end

  test "use up a token" do
    {:ok, app} =
      Repo.insert(
        App.register_changeset(%App{}, %{
          client_name: "client",
          scopes: "scope",
          redirect_uris: "url"
        })
      )

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

  test "delete authorizations" do
    {:ok, app} =
      Repo.insert(
        App.register_changeset(%App{}, %{
          client_name: "client",
          scopes: "scope",
          redirect_uris: "url"
        })
      )

    user = insert(:user)

    {:ok, auth} = Authorization.create_authorization(app, user)
    {:ok, auth} = Authorization.use_token(auth)

    Authorization.delete_user_authorizations(user)

    {_, invalid} = Authorization.use_token(auth)

    assert auth != invalid
  end
end
