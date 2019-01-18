# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Providers.TwitterCard do
  alias Pleroma.Web.Metadata.Providers.Provider
  alias Pleroma.Web.Metadata

  @behaviour Provider

  @impl Provider
  def build_tags(%{object: object}) do
    if Metadata.activity_nsfw?(object) or object.data["attachment"] == [] do
      build_tags(nil)
    else
      case find_first_acceptable_media_type(object) do
        "image" ->
          [{:meta, [property: "twitter:card", content: "summary_large_image"], []}]

        "audio" ->
          [{:meta, [property: "twitter:card", content: "player"], []}]

        "video" ->
          [{:meta, [property: "twitter:card", content: "player"], []}]

        _ ->
          build_tags(nil)
      end
    end
  end

  @impl Provider
  def build_tags(_) do
    [{:meta, [property: "twitter:card", content: "summary"], []}]
  end

  def find_first_acceptable_media_type(%{data: %{"attachment" => attachment}}) do
    Enum.find_value(attachment, fn attachment ->
      Enum.find_value(attachment["url"], fn url ->
        Enum.find(["image", "audio", "video"], fn media_type ->
          String.starts_with?(url["mediaType"], media_type)
        end)
      end)
    end)
  end
end
