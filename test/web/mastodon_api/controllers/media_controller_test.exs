# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MediaControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub

  import Pleroma.Factory

  describe "media upload" do
    setup do
      user = insert(:user)

      conn =
        build_conn()
        |> assign(:user, user)

      image = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      [conn: conn, image: image]
    end

    clear_config([:media_proxy])
    clear_config([Pleroma.Upload])

    test "returns uploaded image", %{conn: conn, image: image} do
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
  end

  describe "PUT /api/v1/media/:id" do
    setup do
      actor = insert(:user)

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

      [actor: actor, object: object]
    end

    test "updates name of media", %{conn: conn, actor: actor, object: object} do
      media =
        conn
        |> assign(:user, actor)
        |> put("/api/v1/media/#{object.id}", %{"description" => "test-media"})
        |> json_response(:ok)

      assert media["description"] == "test-media"
      assert refresh_record(object).data["name"] == "test-media"
    end

    test "returns error wheb request is bad", %{conn: conn, actor: actor, object: object} do
      media =
        conn
        |> assign(:user, actor)
        |> put("/api/v1/media/#{object.id}", %{})
        |> json_response(400)

      assert media == %{"error" => "bad_request"}
    end
  end
end
