# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MediaControllerTest do
  use Pleroma.Web.ConnCase

  import ExUnit.CaptureLog
  import Mox

  alias Pleroma.Object
  alias Pleroma.UnstubbedConfigMock, as: ConfigMock
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub

  describe "Upload media" do
    setup do: oauth_access(["write:media"])

    setup do
      ConfigMock
      |> stub_with(Pleroma.Test.StaticConfig)

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
        |> json_response_and_validate_schema(200)

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
      clear_config([Pleroma.Upload, :uploader], Pleroma.Uploaders.Local)
      desc = "Description of the binary"

      upload_limit = Config.get([:instance, :upload_limit]) * 8 + 8

      File.mkdir_p!(Path.absname("test/tmp"))

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
               |> json_response_and_validate_schema(200)

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

    test "Do not allow nested filename", %{conn: conn, image: image} do
      image = %Plug.Upload{
        image
        | filename: "../../../../../nested/file.jpg"
      }

      desc = "Description of the image"

      media =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/v1/media", %{"file" => image, "description" => desc})
        |> json_response_and_validate_schema(:ok)

      refute Regex.match?(~r"/nested/", media["url"])
    end
  end

  describe "Update media description" do
    setup do: oauth_access(["write:media"])

    setup %{user: actor} do
      ConfigMock
      |> stub_with(Pleroma.Test.StaticConfig)

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
      ConfigMock
      |> stub_with(Pleroma.Test.StaticConfig)

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

  describe "Content-Type sanitization" do
    setup do: oauth_access(["write:media", "read:media"])

    setup do
      ConfigMock
      |> stub_with(Pleroma.Test.StaticConfig)

      config =
        Pleroma.Config.get([Pleroma.Upload])
        |> Keyword.put(:uploader, Pleroma.Uploaders.Local)

      clear_config([Pleroma.Upload], config)
      clear_config([Pleroma.Upload, :allowed_mime_types], ["image", "audio", "video"])

      # Create a file with a malicious content type and dangerous extension
      malicious_file = %Plug.Upload{
        content_type: "application/activity+json",
        path: Path.absname("test/fixtures/image.jpg"),
        # JSON extension to make MIME.from_path detect application/json
        filename: "malicious.json"
      }

      [malicious_file: malicious_file]
    end

    test "sanitizes malicious content types when serving media", %{
      conn: conn,
      malicious_file: malicious_file
    } do
      # First upload the file with the malicious content type
      media =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/v1/media", %{"file" => malicious_file})
        |> json_response_and_validate_schema(:ok)

      # Get the file URL from the response
      url = media["url"]

      # Now make a direct request to the media URL and check the content-type header
      response =
        build_conn()
        |> get(URI.parse(url).path)

      # Find the content-type header
      content_type_header =
        Enum.find(response.resp_headers, fn {name, _} -> name == "content-type" end)

      # The server should detect the application/json MIME type from the .json extension
      # and replace it with application/octet-stream since it's not in allowed_mime_types
      assert content_type_header == {"content-type", "application/octet-stream"}

      # Verify that the file was still served correctly
      assert response.status == 200
    end

    test "allows safe content types", %{conn: conn} do
      safe_image = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "safe_image.jpg"
      }

      # Upload a file with a safe content type
      media =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/v1/media", %{"file" => safe_image})
        |> json_response_and_validate_schema(:ok)

      # Get the file URL from the response
      url = media["url"]

      # Make a direct request to the media URL and check the content-type header
      response =
        build_conn()
        |> get(URI.parse(url).path)

      # The server should preserve the image/jpeg MIME type since it's allowed
      content_type_header =
        Enum.find(response.resp_headers, fn {name, _} -> name == "content-type" end)

      assert content_type_header == {"content-type", "image/jpeg"}

      # Verify that the file was served correctly
      assert response.status == 200
    end
  end
end
