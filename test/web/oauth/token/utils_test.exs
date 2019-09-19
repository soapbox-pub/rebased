# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.Token.UtilsTest do
  use Pleroma.DataCase
  alias Pleroma.Web.OAuth.Token.Utils
  import Pleroma.Factory

  describe "fetch_app/1" do
    test "returns error when credentials is invalid" do
      assert {:error, :not_found} =
               Utils.fetch_app(%Plug.Conn{params: %{"client_id" => 1, "client_secret" => "x"}})
    end

    test "returns App by params credentails" do
      app = insert(:oauth_app)

      assert {:ok, load_app} =
               Utils.fetch_app(%Plug.Conn{
                 params: %{"client_id" => app.client_id, "client_secret" => app.client_secret}
               })

      assert load_app == app
    end

    test "returns App by header credentails" do
      app = insert(:oauth_app)
      header = "Basic " <> Base.encode64("#{app.client_id}:#{app.client_secret}")

      conn =
        %Plug.Conn{}
        |> Plug.Conn.put_req_header("authorization", header)

      assert {:ok, load_app} = Utils.fetch_app(conn)
      assert load_app == app
    end
  end

  describe "format_created_at/1" do
    test "returns formatted created at" do
      token = insert(:oauth_token)
      date = Utils.format_created_at(token)

      token_date =
        token.inserted_at
        |> DateTime.from_naive!("Etc/UTC")
        |> DateTime.to_unix()

      assert token_date == date
    end
  end
end
