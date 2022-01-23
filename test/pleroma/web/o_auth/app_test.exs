# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.AppTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.OAuth.App
  import Pleroma.Factory

  describe "get_or_make/2" do
    test "gets exist app" do
      attrs = %{client_name: "Mastodon-Local", redirect_uris: "."}
      app = insert(:oauth_app, Map.merge(attrs, %{scopes: ["read", "write"]}))
      {:ok, %App{} = exist_app} = App.get_or_make(attrs, [])
      assert exist_app == app
    end

    test "make app" do
      attrs = %{client_name: "Mastodon-Local", redirect_uris: "."}
      {:ok, %App{} = app} = App.get_or_make(attrs, ["write"])
      assert app.scopes == ["write"]
    end

    test "gets exist app and updates scopes" do
      attrs = %{client_name: "Mastodon-Local", redirect_uris: "."}
      app = insert(:oauth_app, Map.merge(attrs, %{scopes: ["read", "write"]}))
      {:ok, %App{} = exist_app} = App.get_or_make(attrs, ["read", "write", "follow", "push"])
      assert exist_app.id == app.id
      assert exist_app.scopes == ["read", "write", "follow", "push"]
    end

    test "has unique client_id" do
      insert(:oauth_app, client_name: "", redirect_uris: "", client_id: "boop")

      error =
        catch_error(insert(:oauth_app, client_name: "", redirect_uris: "", client_id: "boop"))

      assert %Ecto.ConstraintError{} = error
      assert error.constraint == "apps_client_id_index"
      assert error.type == :unique
    end
  end

  test "get_user_apps/1" do
    user = insert(:user)

    apps = [
      insert(:oauth_app, user_id: user.id),
      insert(:oauth_app, user_id: user.id),
      insert(:oauth_app, user_id: user.id)
    ]

    assert App.get_user_apps(user) == apps
  end
end
