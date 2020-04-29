# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MediaControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub

  setup do: oauth_access(["write:media"])

  describe "Upload media" do
    setup do
      image = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      [image: image]
    end

    setup do: clear_config([:media_proxy])
    setup do: clear_config([Pleroma.Upload])

    test "/api/v1/media", %{conn: conn, image: image} do
      desc = "Description of the image"

      media =
        conn
        |> post("/api/v1/media", %{"file" => image, "description" => desc})
        |> json_response(:ok)

      assert media["type"] == "image"
      assert media["description"] == desc
      assert media["id"]

      object = Object.get_by_id(media["id"])
      assert object.data["actor"] == User.ap_id(conn.assigns[:user])
    end

    test "/api/v2/media", %{conn: conn, image: image} do
      desc = "Description of the image"

      response =
        conn
        |> post("/api/v2/media", %{"file" => image, "description" => desc})
        |> json_response(202)

      assert media_id = response["id"]

      media =
        conn
        |> get("/api/v1/media/#{media_id}")
        |> json_response(200)

      assert media["type"] == "image"
      assert media["description"] == desc
      assert media["id"]
      object = Object.get_by_id(media["id"])
      assert object.data["actor"] == User.ap_id(conn.assigns[:user])
    end
  end

  describe "Update media description" do
    setup %{user: actor} do
      file = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      {:ok, %Object{} = object} =
        ActivityPub.upload(
          file,
          actor: User.ap_id(actor),
          description: "test-m"
        )

      [object: object]
    end

    test "/api/v1/media/:id good request", %{conn: conn, object: object} do
      media =
        conn
        |> put("/api/v1/media/#{object.id}", %{"description" => "test-media"})
        |> json_response(:ok)

      assert media["description"] == "test-media"
      assert refresh_record(object).data["name"] == "test-media"
    end

    test "/api/v1/media/:id bad request", %{conn: conn, object: object} do
      media =
        conn
        |> put("/api/v1/media/#{object.id}", %{})
        |> json_response(400)

      assert media == %{"error" => "bad_request"}
    end
  end

  describe "Get media by id" do
    setup %{user: actor} do
      file = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      {:ok, %Object{} = object} =
        ActivityPub.upload(
          file,
          actor: User.ap_id(actor),
          description: "test-media"
        )

      [object: object]
    end

    test "/api/v1/media/:id", %{conn: conn, object: object} do
      media =
        conn
        |> get("/api/v1/media/#{object.id}")
        |> json_response(:ok)

      assert media["description"] == "test-media"
      assert media["type"] == "image"
      assert media["id"]
    end
  end
end
