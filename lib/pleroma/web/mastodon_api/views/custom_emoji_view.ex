# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.CustomEmojiView do
  use Pleroma.Web, :view

  alias Pleroma.Emoji
  alias Pleroma.Web

  def render("index.json", %{custom_emojis: custom_emojis}) do
    render_many(custom_emojis, __MODULE__, "show.json")
  end

  def render("show.json", %{custom_emoji: {shortcode, %Emoji{file: relative_url, tags: tags}}}) do
    url = Web.base_url() |> URI.merge(relative_url) |> to_string()

    %{
      "shortcode" => shortcode,
      "static_url" => url,
      "visible_in_picker" => true,
      "url" => url,
      "tags" => tags,
      # Assuming that a comma is authorized in the category name
      "category" => tags |> List.delete("Custom") |> Enum.join(",")
    }
  end
end
