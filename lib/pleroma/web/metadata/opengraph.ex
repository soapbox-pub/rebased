# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Pleroma.Web.Metadata.Providers.OpenGraph do
  alias Pleroma.Web.Metadata.Providers.Provider
  alias Pleroma.Web.Metadata
  alias Pleroma.{HTML, Formatter, User}
  alias Pleroma.Web.MediaProxy

  @behaviour Provider

  @impl Provider
  def build_tags(%{activity: %{data: %{"object" => %{"id" => object_id}}} = activity, user: user}) do
    attachments = build_attachments(activity)

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
         content: "#{user.name}: " <> "“" <> scrub_html_and_truncate(activity) <> "”"
       ], []},
      {:meta, [property: "og:url", content: object_id], []},
      {:meta,
       [
         property: "og:description",
         content: "#{user_name_string(user)}: " <> "“" <> scrub_html_and_truncate(activity) <> "”"
       ], []},
      {:meta, [property: "og:type", content: "website"], []}
    ] ++
      if attachments == [] or Metadata.activity_nsfw?(activity) do
        [
          {:meta, [property: "og:image", content: attachment_url(User.avatar_url(user))], []},
          {:meta, [property: "og:image:width", content: 150], []},
          {:meta, [property: "og:image:height", content: 150], []}
        ]
      else
        attachments
      end
  end

  @impl Provider
  def build_tags(%{user: user}) do
    with truncated_bio = scrub_html_and_truncate(user.bio || "") do
      [
        {:meta,
         [
           property: "og:title",
           content: user_name_string(user)
         ], []},
        {:meta, [property: "og:url", content: User.profile_url(user)], []},
        {:meta, [property: "og:description", content: truncated_bio], []},
        {:meta, [property: "og:type", content: "website"], []},
        {:meta, [property: "og:image", content: attachment_url(User.avatar_url(user))], []},
        {:meta, [property: "og:image:width", content: 150], []},
        {:meta, [property: "og:image:height", content: 150], []}
      ]
    end
  end

  defp build_attachments(%{data: %{"object" => %{"attachment" => attachments}}} = _activity) do
    Enum.reduce(attachments, [], fn attachment, acc ->
      rendered_tags =
        Enum.reduce(attachment["url"], [], fn url, acc ->
          media_type =
            Enum.find(["image", "audio", "video"], fn media_type ->
              String.starts_with?(url["mediaType"], media_type)
            end)

          # TODO: Add additional properties to objects when we have the data available.
          # Also, Whatsapp only wants JPEG or PNGs. It seems that if we add a second og:image
          # object when a Video or GIF is attached it will display that in the Whatsapp Rich Preview.
          case media_type do
            "audio" ->
              [
                {:meta, [property: "og:" <> media_type, content: attachment_url(url["href"])], []}
                | acc
              ]

            "image" ->
              [
                {:meta, [property: "og:" <> media_type, content: attachment_url(url["href"])],
                 []},
                {:meta, [property: "og:image:width", content: 150], []},
                {:meta, [property: "og:image:height", content: 150], []}
                | acc
              ]

            "video" ->
              [
                {:meta, [property: "og:" <> media_type, content: attachment_url(url["href"])], []}
                | acc
              ]

            _ ->
              acc
          end
        end)

      acc ++ rendered_tags
    end)
  end

  defp scrub_html_and_truncate(%{data: %{"object" => %{"content" => content}}} = activity) do
    content
    # html content comes from DB already encoded, decode first and scrub after
    |> HtmlEntities.decode()
    |> String.replace(~r/<br\s?\/?>/, " ")
    |> HTML.get_cached_stripped_html_for_object(activity, __MODULE__)
    |> Formatter.truncate()
  end

  defp scrub_html_and_truncate(content) when is_binary(content) do
    content
    # html content comes from DB already encoded, decode first and scrub after
    |> HtmlEntities.decode()
    |> String.replace(~r/<br\s?\/?>/, " ")
    |> HTML.strip_tags()
    |> Formatter.truncate()
  end

  defp attachment_url(url) do
    MediaProxy.url(url)
  end

  defp user_name_string(user) do
    "#{user.name} " <>
      if user.local do
        "(@#{user.nickname}@#{Pleroma.Web.Endpoint.host()})"
      else
        "(@#{user.nickname})"
      end
  end
end
