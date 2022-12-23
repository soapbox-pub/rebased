# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.DirectoryControllerTest do
  use Pleroma.Web.ConnCase, async: true
  alias Pleroma.Web.CommonAPI
  import Pleroma.Factory

  test "GET /api/v1/directory with :profile_directory disabled returns empty array", %{conn: conn} do
    clear_config([:instance, :profile_directory], false)

    insert(:user, is_discoverable: true)
    insert(:user, is_discoverable: true)

    result =
      conn
      |> get("/api/v1/directory")
      |> json_response_and_validate_schema(200)

    assert result == []
  end

  test "GET /api/v1/directory returns discoverable users only", %{conn: conn} do
    %{id: user_id} = insert(:user, is_discoverable: true)
    insert(:user, is_discoverable: false)

    result =
      conn
      |> get("/api/v1/directory")
      |> json_response_and_validate_schema(200)

    assert [%{"id" => ^user_id}] = result
  end

  test "GET /api/v1/directory returns users sorted by most recent statuses", %{conn: conn} do
    insert(:user, is_discoverable: true)
    %{id: user_id} = user = insert(:user, is_discoverable: true)
    insert(:user, is_discoverable: true)

    {:ok, _activity} = CommonAPI.post(user, %{status: "yay i'm discoverable"})

    result =
      conn
      |> get("/api/v1/directory?order=active")
      |> json_response_and_validate_schema(200)

    assert [%{"id" => ^user_id} | _tail] = result
  end
end
