# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MediaControllerTest do
  use Pleroma.Web.ConnCase

  import ExUnit.CaptureLog

  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub

  describe "Upload media" do
    setup do: oauth_access(["write:media"])

    setup do
      image = %Plug.Upload{
        content_type: "image/jpeg",
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
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/v1/media", %{"file" => image, "description" => desc})
        |> json_response_and_validate_schema(:ok)

      assert media["type"] == "image"
      assert media["description"] == desc
      assert media["id"]

      object = Object.get_by_id(media["id"])
      assert object.data["actor"] == User.ap_id(conn.assigns[:user])
    end

    test "/api/v2/media", %{conn: conn, user: user, image: image} do
      desc = "Description of the image"

      response =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/v2/media", %{"file" => image, "description" => desc})
        |> json_response_and_validate_schema(202)

      assert media_id = response["id"]

      %{conn: conn} = oauth_access(["read:media"], user: user)

      media =
        conn
        |> get("/api/v1/media/#{media_id}")
        |> json_response_and_validate_schema(200)

      assert media["type"] == "image"
      assert media["description"] == desc
      assert media["id"]

      object = Object.get_by_id(media["id"])
      assert object.data["actor"] == user.ap_id
    end

    test "/api/v2/media, upload_limit", %{conn: conn, user: user} do
      desc = "Description of the binary"

      upload_limit = Config.get([:instance, :upload_limit]) * 8 + 8

      assert :ok ==
               File.write(Path.absname("test/tmp/large_binary.data"), <<0::size(upload_limit)>>)

      large_binary = %Plug.Upload{
        content_type: nil,
        path: Path.absname("test/tmp/large_binary.data"),
        filename: "large_binary.data"
      }

      assert capture_log(fn ->
               assert %{"error" => "file_too_large"} =
                        conn
                        |> put_req_header("content-type", "multipart/form-data")
                        |> post("/api/v2/media", %{
                          "file" => large_binary,
                          "description" => desc
                        })
                        |> json_response_and_validate_schema(400)
             end) =~
               "[error] Elixir.Pleroma.Upload store (using Pleroma.Uploaders.Local) failed: :file_too_large"

      clear_config([:instance, :upload_limit], upload_limit)

      assert response =
               conn
               |> put_req_header("content-type", "multipart/form-data")
               |> post("/api/v2/media", %{
                 "file" => large_binary,
                 "description" => desc
               })
               |> json_response_and_validate_schema(202)

      assert media_id = response["id"]

      %{conn: conn} = oauth_access(["read:media"], user: user)

      media =
        conn
        |> get("/api/v1/media/#{media_id}")
        |> json_response_and_validate_schema(200)

      assert media["type"] == "unknown"
      assert media["description"] == desc
      assert media["id"]

      assert :ok == File.rm(Path.absname("test/tmp/large_binary.data"))
    end
  end

  describe "Update media description" do
    setup do: oauth_access(["write:media"])

    setup %{user: actor} do
      file = %Plug.Upload{
        content_type: "image/jpeg",
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
        |> put_req_header("content-type", "multipart/form-data")
        |> put("/api/v1/media/#{object.id}", %{"description" => "test-media"})
        |> json_response_and_validate_schema(:ok)

      assert media["description"] == "test-media"
      assert refresh_record(object).data["name"] == "test-media"
    end
  end

  describe "Get media by id (/api/v1/media/:id)" do
    setup do: oauth_access(["read:media"])

    setup %{user: actor} do
      file = %Plug.Upload{
        content_type: "image/jpeg",
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

    test "it returns media object when requested by owner", %{conn: conn, object: object} do
      media =
        conn
        |> get("/api/v1/media/#{object.id}")
        |> json_response_and_validate_schema(:ok)

      assert media["description"] == "test-media"
      assert media["type"] == "image"
      assert media["id"]
    end

    test "it returns 403 if media object requested by non-owner", %{object: object, user: user} do
      %{conn: conn, user: other_user} = oauth_access(["read:media"])

      assert object.data["actor"] == user.ap_id
      refute user.id == other_user.id

      conn
      |> get("/api/v1/media/#{object.id}")
      |> json_response_and_validate_schema(403)
    end
  end
end
