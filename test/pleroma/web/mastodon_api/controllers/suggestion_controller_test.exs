# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.SuggestionControllerTest do
  use Pleroma.Web.ConnCase, async: true

  setup do: oauth_access(["read"])

  test "returns empty result", %{conn: conn} do
    res =
      conn
      |> get("/api/v1/suggestions")
      |> json_response_and_validate_schema(200)

    assert res == []
  end
end
