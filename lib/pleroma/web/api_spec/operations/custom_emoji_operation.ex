# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.CustomEmojiOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.Emoji

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %Operation{
      tags: ["Custom emojis"],
      summary: "Retrieve a list of custom emojis",
      description: "Returns custom emojis that are available on the server.",
      operationId: "CustomEmojiController.index",
      responses: %{
        200 => Operation.response("Custom Emojis", "application/json", resposnse())
      }
    }
  end

  defp resposnse do
    %Schema{
      title: "CustomEmojisResponse",
      description: "Response schema for custom emojis",
      type: :array,
      items: custom_emoji(),
      example: [
        %{
          "category" => "Fun",
          "shortcode" => "blank",
          "static_url" => "https://lain.com/emoji/blank.png",
          "tags" => ["Fun"],
          "url" => "https://lain.com/emoji/blank.png",
          "visible_in_picker" => false
        },
        %{
          "category" => "Gif,Fun",
          "shortcode" => "firefox",
          "static_url" => "https://lain.com/emoji/Firefox.gif",
          "tags" => ["Gif", "Fun"],
          "url" => "https://lain.com/emoji/Firefox.gif",
          "visible_in_picker" => true
        },
        %{
          "category" => "pack:mixed",
          "shortcode" => "sadcat",
          "static_url" => "https://lain.com/emoji/mixed/sadcat.png",
          "tags" => ["pack:mixed"],
          "url" => "https://lain.com/emoji/mixed/sadcat.png",
          "visible_in_picker" => true
        }
      ]
    }
  end

  defp custom_emoji do
    %Schema{
      title: "CustomEmoji",
      description: "Schema for a CustomEmoji",
      allOf: [
        Emoji,
        %Schema{
          type: :object,
          properties: %{
            category: %Schema{type: :string},
            tags: %Schema{type: :array, items: %Schema{type: :string}}
          }
        }
      ],
      example: %{
        "category" => "Fun",
        "shortcode" => "aaaa",
        "url" =>
          "https://files.mastodon.social/custom_emojis/images/000/007/118/original/aaaa.png",
        "static_url" =>
          "https://files.mastodon.social/custom_emojis/images/000/007/118/static/aaaa.png",
        "visible_in_picker" => true,
        "tags" => ["Gif", "Fun"]
      }
    }
  end
end
