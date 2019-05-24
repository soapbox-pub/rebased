# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MongooseIMController do
  use Pleroma.Web.ConnCase
  import Pleroma.Factory

  test "/user_exists", %{conn: conn} do
    _user = insert(:user, nickname: "lain")
    _remote_user = insert(:user, nickname: "alice", local: false)

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
  end

  test "/check_password", %{conn: conn} do
    user = insert(:user, password_hash: Comeonin.Pbkdf2.hashpwsalt("cool"))

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
      |> get(mongoose_im_path(conn, :check_password), user: "nobody", pass: "cool")
      |> json_response(404)

    assert res == false
  end
end
