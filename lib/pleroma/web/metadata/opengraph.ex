# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Providers.OpenGraph do
  alias Pleroma.User
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
    # Zero width space
    content =
      if scrubbed_content != "" and scrubbed_content != "\u200B" do
        ": “" <> scrubbed_content <> "”"
      else
        ""
      end

    # Most previews only show og:title which is inconvenient. Instagram
    # hacks this by putting the description in the title and making the
    # description longer prefixed by how many likes and shares the post
    # has. Here we use the descriptive nickname in the title, and expand
    # the full account & nickname in the description. We also use the cute^Wevil
    # smart quotes around the status text like Instagram, too.
    [
      {:meta,
       [
         property: "og:title",
         content: "#{user.name}" <> content
       ], []},
      {:meta, [property: "og:url", content: url], []},
      {:meta,
       [
         property: "og:description",
         content: "#{Utils.user_name_string(user)}" <> content
       ], []},
      {:meta, [property: "og:type", content: "website"], []}
    ] ++
      if attachments == [] or Metadata.activity_nsfw?(object) do
        [
          {:meta, [property: "og:image", content: Utils.attachment_url(User.avatar_url(user))],
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
    with truncated_bio = Utils.scrub_html_and_truncate(user.bio || "") do
      [
        {:meta,
         [
           property: "og:title",
           content: Utils.user_name_string(user)
         ], []},
        {:meta, [property: "og:url", content: User.profile_url(user)], []},
        {:meta, [property: "og:description", content: truncated_bio], []},
        {:meta, [property: "og:type", content: "website"], []},
        {:meta, [property: "og:image", content: Utils.attachment_url(User.avatar_url(user))], []},
        {:meta, [property: "og:image:width", content: 150], []},
        {:meta, [property: "og:image:height", content: 150], []}
      ]
    end
  end

  defp build_attachments(%{data: %{"attachment" => attachments}}) do
    Enum.reduce(attachments, [], fn attachment, acc ->
      rendered_tags =
        Enum.reduce(attachment["url"], [], fn url, acc ->
          # TODO: Add additional properties to objects when we have the data available.
          # Also, Whatsapp only wants JPEG or PNGs. It seems that if we add a second og:image
          # object when a Video or GIF is attached it will display that in Whatsapp Rich Preview.
          case Utils.fetch_media_type(@media_types, url["mediaType"]) do
            "audio" ->
              [
                {:meta, [property: "og:audio", content: Utils.attachment_url(url["href"])], []}
                | acc
              ]

            "image" ->
              [
                {:meta, [property: "og:image", content: Utils.attachment_url(url["href"])], []},
                {:meta, [property: "og:image:width", content: 150], []},
                {:meta, [property: "og:image:height", content: 150], []}
                | acc
              ]

            "video" ->
              [
                {:meta, [property: "og:video", content: Utils.attachment_url(url["href"])], []}
                | acc
              ]

            _ ->
              acc
          end
        end)

      acc ++ rendered_tags
    end)
  end

  defp build_attachments(_), do: []
end
