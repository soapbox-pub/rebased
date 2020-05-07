# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Auth.PleromaAuthenticatorTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Web.Auth.PleromaAuthenticator
  import Pleroma.Factory

  setup do
    password = "testpassword"
    name = "AgentSmith"
    user = insert(:user, nickname: name, password_hash: Comeonin.Pbkdf2.hashpwsalt(password))
    {:ok, [user: user, name: name, password: password]}
  end

  test "get_user/authorization", %{user: user, name: name, password: password} do
    params = %{"authorization" => %{"name" => name, "password" => password}}
    res = PleromaAuthenticator.get_user(%Plug.Conn{params: params})

    assert {:ok, user} == res
  end

  test "get_user/authorization with invalid password", %{name: name} do
    params = %{"authorization" => %{"name" => name, "password" => "password"}}
    res = PleromaAuthenticator.get_user(%Plug.Conn{params: params})

    assert {:error, {:checkpw, false}} == res
  end

  test "get_user/grant_type_password", %{user: user, name: name, password: password} do
    params = %{"grant_type" => "password", "username" => name, "password" => password}
    res = PleromaAuthenticator.get_user(%Plug.Conn{params: params})

    assert {:ok, user} == res
  end

  test "error credintails" do
    res = PleromaAuthenticator.get_user(%Plug.Conn{params: %{}})
    assert {:error, :invalid_credentials} == res
  end
end
