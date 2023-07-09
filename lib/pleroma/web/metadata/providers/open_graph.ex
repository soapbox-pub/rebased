# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Providers.OpenGraph do
  alias Pleroma.User
  alias Pleroma.Web.MediaProxy
  alias Pleroma.Web.Metadata
  alias Pleroma.Web.Metadata.Providers.Provider
  alias Pleroma.Web.Metadata.Utils

  @behaviour Provider
  @media_types ["image", "audio", "video"]

  @impl Provider
  def build_tags(%{
        object: object,
        url: url,
        user: user
      }) do
    attachments = build_attachments(object)
    scrubbed_content = Utils.scrub_html_and_truncate(object)

    [
      {:meta,
       [
         property: "og:title",
         content: Utils.user_name_string(user)
       ], []},
      {:meta, [property: "og:url", content: url], []},
      {:meta,
       [
         property: "og:description",
         content: scrubbed_content
       ], []},
      {:meta, [property: "og:type", content: "article"], []}
    ] ++
      if attachments == [] or Metadata.activity_nsfw?(object) do
        [
          {:meta, [property: "og:image", content: MediaProxy.preview_url(User.avatar_url(user))],
           []},
          {:meta, [property: "og:image:width", content: 150], []},
          {:meta, [property: "og:image:height", content: 150], []}
        ]
      else
        attachments
      end
  end

  @impl Provider
  def build_tags(%{user: user}) do
    with truncated_bio = Utils.scrub_html_and_truncate(user.bio) do
      [
        {:meta,
         [
           property: "og:title",
           content: Utils.user_name_string(user)
         ], []},
        {:meta, [property: "og:url", content: user.uri || user.ap_id], []},
        {:meta, [property: "og:description", content: truncated_bio], []},
        {:meta, [property: "og:type", content: "article"], []},
        {:meta, [property: "og:image", content: MediaProxy.preview_url(User.avatar_url(user))],
         []},
        {:meta, [property: "og:image:width", content: 150], []},
        {:meta, [property: "og:image:height", content: 150], []}
      ]
    end
  end

  defp build_attachments(%{data: %{"attachment" => attachments}}) do
    Enum.reduce(attachments, [], fn attachment, acc ->
      rendered_tags =
        Enum.reduce(attachment["url"], [], fn url, acc ->
          # TODO: Whatsapp only wants JPEG or PNGs. It seems that if we add a second og:image
          # object when a Video or GIF is attached it will display that in Whatsapp Rich Preview.
          case Utils.fetch_media_type(@media_types, url["mediaType"]) do
            "audio" ->
              [
                {:meta, [property: "og:audio", content: MediaProxy.url(url["href"])], []}
                | acc
              ]

            # Not using preview_url for this. It saves bandwidth, but the image dimensions will
            # be wrong. We generate it on the fly and have no way to capture or analyze the
            # image to get the dimensions. This can be an issue for apps/FEs rendering images
            # in timelines too, but you can get clever with the aspect ratio metadata as a
            # workaround.
            "image" ->
              [
                {:meta, [property: "og:image", content: MediaProxy.url(url["href"])], []},
                {:meta, [property: "og:image:alt", content: attachment["name"]], []}
                | acc
              ]
              |> maybe_add_dimensions(url)

            "video" ->
              [
                {:meta, [property: "og:video", content: MediaProxy.url(url["href"])], []}
                | acc
              ]
              |> maybe_add_dimensions(url)
              |> maybe_add_video_thumbnail(url)

            _ ->
              acc
          end
        end)

      acc ++ rendered_tags
    end)
  end

  defp build_attachments(_), do: []

  # We can use url["mediaType"] to dynamically fill the metadata
  defp maybe_add_dimensions(metadata, url) do
    type = url["mediaType"] |> String.split("/") |> List.first()

    cond do
      !is_nil(url["height"]) && !is_nil(url["width"]) ->
        metadata ++
          [
            {:meta, [property: "og:#{type}:width", content: "#{url["width"]}"], []},
            {:meta, [property: "og:#{type}:height", content: "#{url["height"]}"], []}
          ]

      true ->
        metadata
    end
  end

  # Media Preview Proxy makes thumbnails of videos without resizing, so we can trust the
  # width and height of the source video.
  defp maybe_add_video_thumbnail(metadata, url) do
    cond do
      Pleroma.Config.get([:media_preview_proxy, :enabled], false) ->
        metadata ++
          [
            {:meta, [property: "og:image:width", content: "#{url["width"]}"], []},
            {:meta, [property: "og:image:height", content: "#{url["height"]}"], []},
            {:meta, [property: "og:image", content: MediaProxy.preview_url(url["href"])], []}
          ]

      true ->
        metadata
    end
  end
end
