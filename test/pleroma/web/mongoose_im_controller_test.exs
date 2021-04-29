# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MongooseIMControllerTest do
  use Pleroma.Web.ConnCase, async: true
  import Pleroma.Factory

  test "/user_exists", %{conn: conn} do
    _user = insert(:user, nickname: "lain")
    _remote_user = insert(:user, nickname: "alice", local: false)
    _deactivated_user = insert(:user, nickname: "konata", is_active: false)

    res =
      conn
      |> get(mongoose_im_path(conn, :user_exists), user: "lain")
      |> json_response(200)

    assert res == true

    res =
      conn
      |> get(mongoose_im_path(conn, :user_exists), user: "alice")
      |> json_response(404)

    assert res == false

    res =
      conn
      |> get(mongoose_im_path(conn, :user_exists), user: "bob")
      |> json_response(404)

    assert res == false

    res =
      conn
      |> get(mongoose_im_path(conn, :user_exists), user: "konata")
      |> json_response(404)

    assert res == false
  end

  test "/check_password", %{conn: conn} do
    user = insert(:user, password_hash: Pleroma.Password.Pbkdf2.hash_pwd_salt("cool"))

    _deactivated_user =
      insert(:user,
        nickname: "konata",
        is_active: false,
        password_hash: Pleroma.Password.Pbkdf2.hash_pwd_salt("cool")
      )

    res =
      conn
      |> get(mongoose_im_path(conn, :check_password), user: user.nickname, pass: "cool")
      |> json_response(200)

    assert res == true

    res =
      conn
      |> get(mongoose_im_path(conn, :check_password), user: user.nickname, pass: "uncool")
      |> json_response(403)

    assert res == false

    res =
      conn
      |> get(mongoose_im_path(conn, :check_password), user: "konata", pass: "cool")
      |> json_response(404)

    assert res == false

    res =
      conn
      |> get(mongoose_im_path(conn, :check_password), user: "nobody", pass: "cool")
      |> json_response(404)

    assert res == false
  end
end
