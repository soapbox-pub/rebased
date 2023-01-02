# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.MascotControllerTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.User

  test "mascot upload" do
    %{conn: conn} = oauth_access(["write:accounts"])

    non_image_file = %Plug.Upload{
      content_type: "audio/mpeg",
      path: Path.absname("test/fixtures/sound.mp3"),
      filename: "sound.mp3"
    }

    ret_conn =
      conn
      |> put_req_header("content-type", "multipart/form-data")
      |> put("/api/v1/pleroma/mascot", %{"file" => non_image_file})

    assert json_response_and_validate_schema(ret_conn, 415)

    file = %Plug.Upload{
      content_type: "image/jpeg",
      path: Path.absname("test/fixtures/image.jpg"),
      filename: "an_image.jpg"
    }

    conn =
      conn
      |> put_req_header("content-type", "multipart/form-data")
      |> put("/api/v1/pleroma/mascot", %{"file" => file})

    assert %{"id" => _, "type" => _image} = json_response_and_validate_schema(conn, 200)
  end

  test "mascot retrieving" do
    %{user: user, conn: conn} = oauth_access(["read:accounts", "write:accounts"])

    # When user hasn't set a mascot, we should just get pleroma tan back
    ret_conn = get(conn, "/api/v1/pleroma/mascot")

    assert %{"url" => url} = json_response_and_validate_schema(ret_conn, 200)
    assert url =~ "pleroma-fox-tan-smol"

    # When a user sets their mascot, we should get that back
    file = %Plug.Upload{
      content_type: "image/jpeg",
      path: Path.absname("test/fixtures/image.jpg"),
      filename: "an_image.jpg"
    }

    ret_conn =
      conn
      |> put_req_header("content-type", "multipart/form-data")
      |> put("/api/v1/pleroma/mascot", %{"file" => file})

    assert json_response_and_validate_schema(ret_conn, 200)

    user = User.get_cached_by_id(user.id)

    conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/pleroma/mascot")

    assert %{"url" => url, "type" => "image"} = json_response_and_validate_schema(conn, 200)
    assert url =~ "an_image"
  end
end
