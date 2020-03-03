# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.UploaderControllerTest do
  use Pleroma.Web.ConnCase
  alias Pleroma.Uploaders.Uploader

  describe "callback/2" do
    test "it returns 400 response when process callback isn't alive", %{conn: conn} do
      res =
        conn
        |> post(uploader_path(conn, :callback, "test-path"))

      assert res.status == 400
      assert res.resp_body == "{\"error\":\"bad request\"}"
    end

    test "it returns success result", %{conn: conn} do
      task =
        Task.async(fn ->
          receive do
            {Uploader, pid, conn, _params} ->
              conn =
                conn
                |> put_status(:ok)
                |> Phoenix.Controller.json(%{upload_path: "test-path"})

              send(pid, {Uploader, conn})
          end
        end)

      :global.register_name({Uploader, "test-path"}, task.pid)

      res =
        conn
        |> post(uploader_path(conn, :callback, "test-path"))
        |> json_response(200)

      assert res == %{"upload_path" => "test-path"}
    end
  end
end
