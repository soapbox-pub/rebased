# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.BiteControllerTest do
  use Pleroma.Web.ConnCase
  import Pleroma.Factory

  setup do: oauth_access(["write:bites"])

  test "bites a user", %{conn: conn} do
    %{id: bitten_id} = insert(:user)

    response =
      conn
      |> post("/api/v1/bite?id=#{bitten_id}")
      |> json_response_and_validate_schema(200)

    assert response == %{}
  end

  test "self harm is not supported", %{conn: conn, user: %{id: self_id}} do
    response =
      conn
      |> post("/api/v1/bite?id=#{self_id}")
      |> json_response_and_validate_schema(400)

    assert %{"error" => "Can not bite yourself"} = response
  end
end
