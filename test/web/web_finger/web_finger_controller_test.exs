# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.WebFinger.WebFingerControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory
  import Tesla.Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)

    config_path = [:instance, :federating]
    initial_setting = Pleroma.Config.get(config_path)

    Pleroma.Config.put(config_path, true)
    on_exit(fn -> Pleroma.Config.put(config_path, initial_setting) end)
    :ok
  end

  test "Webfinger JRD" do
    user = insert(:user)

    response =
      build_conn()
      |> put_req_header("accept", "application/jrd+json")
      |> get("/.well-known/webfinger?resource=acct:#{user.nickname}@localhost")

    assert json_response(response, 200)["subject"] == "acct:#{user.nickname}@localhost"
  end

  test "Webfinger XML" do
    user = insert(:user)

    response =
      build_conn()
      |> put_req_header("accept", "application/xrd+xml")
      |> get("/.well-known/webfinger?resource=acct:#{user.nickname}@localhost")

    assert response(response, 200)
  end

  test "Sends a 400 when resource param is missing" do
    response =
      build_conn()
      |> put_req_header("accept", "application/xrd+xml,application/jrd+json")
      |> get("/.well-known/webfinger")

    assert response(response, 400)
  end
end
