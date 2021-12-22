# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.ScheduledStatus do
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Attachment
  alias Pleroma.Web.ApiSpec.Schemas.VisibilityScope
  alias Pleroma.Web.ApiSpec.StatusOperation

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "ScheduledStatus",
    description: "Represents a status that will be published at a future scheduled date.",
    type: :object,
    required: [:id, :scheduled_at, :params],
    properties: %{
      id: %Schema{type: :string},
      scheduled_at: %Schema{type: :string, format: :"date-time"},
      media_attachments: %Schema{type: :array, items: Attachment},
      params: %Schema{
        type: :object,
        required: [:text, :visibility],
        properties: %{
          text: %Schema{type: :string, nullable: true},
          media_ids: %Schema{type: :array, nullable: true, items: %Schema{type: :string}},
          sensitive: %Schema{type: :boolean, nullable: true},
          spoiler_text: %Schema{type: :string, nullable: true},
          visibility: %Schema{allOf: [VisibilityScope], nullable: true},
          scheduled_at: %Schema{type: :string, format: :"date-time", nullable: true},
          poll: StatusOperation.poll_params(),
          in_reply_to_id: %Schema{type: :string, nullable: true},
          expires_in: %Schema{type: :integer, nullable: true}
        }
      }
    },
    example: %{
      id: "3221",
      scheduled_at: "2019-12-05T12:33:01.000Z",
      params: %{
        text: "test content",
        media_ids: nil,
        sensitive: nil,
        spoiler_text: nil,
        visibility: nil,
        scheduled_at: nil,
        poll: nil,
        idempotency: nil,
        in_reply_to_id: nil,
        expires_in: nil
      },
      media_attachments: [Attachment.schema().example]
    }
  })
end
