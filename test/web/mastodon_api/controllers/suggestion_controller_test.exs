# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.SuggestionControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Config

  import ExUnit.CaptureLog
  import Pleroma.Factory
  import Tesla.Mock

  setup do: oauth_access(["read"])

  setup %{user: user} do
    other_user = insert(:user)
    host = Config.get([Pleroma.Web.Endpoint, :url, :host])
    url500 = "http://test500?#{host}&#{user.nickname}"
    url200 = "http://test200?#{host}&#{user.nickname}"

    mock(fn
      %{method: :get, url: ^url500} ->
        %Tesla.Env{status: 500, body: "bad request"}

      %{method: :get, url: ^url200} ->
        %Tesla.Env{
          status: 200,
          body:
            ~s([{"acct":"yj455","avatar":"https://social.heldscal.la/avatar/201.jpeg","avatar_static":"https://social.heldscal.la/avatar/s/201.jpeg"}, {"acct":"#{
              other_user.ap_id
            }","avatar":"https://social.heldscal.la/avatar/202.jpeg","avatar_static":"https://social.heldscal.la/avatar/s/202.jpeg"}])
        }
    end)

    [other_user: other_user]
  end

  clear_config(:suggestions)

  test "returns empty result when suggestions disabled", %{conn: conn} do
    Config.put([:suggestions, :enabled], false)

    res =
      conn
      |> get("/api/v1/suggestions")
      |> json_response(200)

    assert res == []
  end

  test "returns error", %{conn: conn} do
    Config.put([:suggestions, :enabled], true)
    Config.put([:suggestions, :third_party_engine], "http://test500?{{host}}&{{user}}")

    assert capture_log(fn ->
             res =
               conn
               |> get("/api/v1/suggestions")
               |> json_response(500)

             assert res == "Something went wrong"
           end) =~ "Could not retrieve suggestions"
  end

  test "returns suggestions", %{conn: conn, other_user: other_user} do
    Config.put([:suggestions, :enabled], true)
    Config.put([:suggestions, :third_party_engine], "http://test200?{{host}}&{{user}}")

    res =
      conn
      |> get("/api/v1/suggestions")
      |> json_response(200)

    assert res == [
             %{
               "acct" => "yj455",
               "avatar" => "https://social.heldscal.la/avatar/201.jpeg",
               "avatar_static" => "https://social.heldscal.la/avatar/s/201.jpeg",
               "id" => 0
             },
             %{
               "acct" => other_user.ap_id,
               "avatar" => "https://social.heldscal.la/avatar/202.jpeg",
               "avatar_static" => "https://social.heldscal.la/avatar/s/202.jpeg",
               "id" => other_user.id
             }
           ]
  end
end
