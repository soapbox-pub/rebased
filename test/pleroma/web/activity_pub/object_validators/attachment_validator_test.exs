# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.AttachmentValidatorTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.ObjectValidators.AttachmentValidator

  import Pleroma.Factory

  describe "attachments" do
    test "works with honkerific attachments" do
      attachment = %{
        "mediaType" => "",
        "name" => "",
        "summary" => "298p3RG7j27tfsZ9RQ.jpg",
        "type" => "Document",
        "url" => "https://honk.tedunangst.com/d/298p3RG7j27tfsZ9RQ.jpg"
      }

      assert {:ok, attachment} =
               AttachmentValidator.cast_and_validate(attachment)
               |> Ecto.Changeset.apply_action(:insert)

      assert attachment.mediaType == "application/octet-stream"
    end

    test "it turns mastodon attachments into our attachments" do
      attachment = %{
        "url" =>
          "http://mastodon.example.org/system/media_attachments/files/000/000/002/original/334ce029e7bfb920.jpg",
        "type" => "Document",
        "name" => nil,
        "mediaType" => "image/jpeg",
        "blurhash" => "UD9jJz~VSbR#xT$~%KtQX9R,WAs9RjWBs:of"
      }

      {:ok, attachment} =
        AttachmentValidator.cast_and_validate(attachment)
        |> Ecto.Changeset.apply_action(:insert)

      assert [
               %{
                 href:
                   "http://mastodon.example.org/system/media_attachments/files/000/000/002/original/334ce029e7bfb920.jpg",
                 type: "Link",
                 mediaType: "image/jpeg"
               }
             ] = attachment.url

      assert attachment.mediaType == "image/jpeg"
      assert attachment.blurhash == "UD9jJz~VSbR#xT$~%KtQX9R,WAs9RjWBs:of"
    end

    test "it handles our own uploads" do
      user = insert(:user)

      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      {:ok, attachment} = ActivityPub.upload(file, actor: user.ap_id)

      {:ok, attachment} =
        attachment.data
        |> AttachmentValidator.cast_and_validate()
        |> Ecto.Changeset.apply_action(:insert)

      assert attachment.mediaType == "image/jpeg"
    end

    test "it handles image dimensions" do
      attachment = %{
        "url" => [
          %{
            "type" => "Link",
            "mediaType" => "image/jpeg",
            "href" => "https://example.com/images/1.jpg",
            "width" => 200,
            "height" => 100
          }
        ],
        "type" => "Document",
        "name" => nil,
        "mediaType" => "image/jpeg"
      }

      {:ok, attachment} =
        AttachmentValidator.cast_and_validate(attachment)
        |> Ecto.Changeset.apply_action(:insert)

      assert [
               %{
                 href: "https://example.com/images/1.jpg",
                 type: "Link",
                 mediaType: "image/jpeg",
                 width: 200,
                 height: 100
               }
             ] = attachment.url

      assert attachment.mediaType == "image/jpeg"
    end
  end
end
