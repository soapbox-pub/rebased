# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.Attachment do
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Attachment",
    description: "Represents a file or media attachment that can be added to a status.",
    type: :object,
    requried: [:id, :url, :preview_url],
    properties: %{
      id: %Schema{type: :string, description: "The ID of the attachment in the database."},
      url: %Schema{
        type: :string,
        format: :uri,
        description: "The location of the original full-size attachment"
      },
      remote_url: %Schema{
        type: :string,
        format: :uri,
        description:
          "The location of the full-size original attachment on the remote website. String (URL), or null if the attachment is local",
        nullable: true
      },
      preview_url: %Schema{
        type: :string,
        format: :uri,
        description: "The location of a scaled-down preview of the attachment"
      },
      text_url: %Schema{
        type: :string,
        format: :uri,
        description: "A shorter URL for the attachment"
      },
      description: %Schema{
        type: :string,
        nullable: true,
        description:
          "Alternate text that describes what is in the media attachment, to be used for the visually impaired or when media attachments do not load"
      },
      type: %Schema{
        type: :string,
        enum: ["image", "video", "audio", "unknown"],
        description: "The type of the attachment"
      },
      pleroma: %Schema{
        type: :object,
        properties: %{
          mime_type: %Schema{type: :string, description: "mime type of the attachment"}
        }
      }
    },
    example: %{
      id: "1638338801",
      type: "image",
      url: "someurl",
      remote_url: "someurl",
      preview_url: "someurl",
      text_url: "someurl",
      description: nil,
      pleroma: %{mime_type: "image/png"}
    }
  })
end
