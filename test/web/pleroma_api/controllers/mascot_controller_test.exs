# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.MascotControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.User

  import Pleroma.Factory

  test "mascot upload", %{conn: conn} do
    user = insert(:user)

    non_image_file = %Plug.Upload{
      content_type: "audio/mpeg",
      path: Path.absname("test/fixtures/sound.mp3"),
      filename: "sound.mp3"
    }

    conn =
      conn
      |> assign(:user, user)
      |> put("/api/v1/pleroma/mascot", %{"file" => non_image_file})

    assert json_response(conn, 415)

    file = %Plug.Upload{
      content_type: "image/jpg",
      path: Path.absname("test/fixtures/image.jpg"),
      filename: "an_image.jpg"
    }

    conn =
      build_conn()
      |> assign(:user, user)
      |> put("/api/v1/pleroma/mascot", %{"file" => file})

    assert %{"id" => _, "type" => image} = json_response(conn, 200)
  end

  test "mascot retrieving", %{conn: conn} do
    user = insert(:user)
    # When user hasn't set a mascot, we should just get pleroma tan back
    conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/pleroma/mascot")

    assert %{"url" => url} = json_response(conn, 200)
    assert url =~ "pleroma-fox-tan-smol"

    # When a user sets their mascot, we should get that back
    file = %Plug.Upload{
      content_type: "image/jpg",
      path: Path.absname("test/fixtures/image.jpg"),
      filename: "an_image.jpg"
    }

    conn =
      build_conn()
      |> assign(:user, user)
      |> put("/api/v1/pleroma/mascot", %{"file" => file})

    assert json_response(conn, 200)

    user = User.get_cached_by_id(user.id)

    conn =
      build_conn()
      |> assign(:user, user)
      |> get("/api/v1/pleroma/mascot")

    assert %{"url" => url, "type" => "image"} = json_response(conn, 200)
    assert url =~ "an_image"
  end
end
