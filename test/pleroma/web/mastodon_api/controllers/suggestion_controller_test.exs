# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.SuggestionControllerTest do
  use Pleroma.Web.ConnCase, async: true
  import Pleroma.Factory

  setup do: oauth_access(["read"])

  test "returns empty result", %{conn: conn} do
    res =
      conn
      |> get("/api/v1/suggestions")
      |> json_response_and_validate_schema(200)

    assert res == []
  end

  test "returns v2 suggestions", %{conn: conn} do
    %{id: user_id} = insert(:user, is_suggested: true)

    res =
      conn
      |> get("/api/v2/suggestions")
      |> json_response_and_validate_schema(200)

    assert [%{"source" => "staff", "account" => %{"id" => ^user_id}}] = res
  end
end
