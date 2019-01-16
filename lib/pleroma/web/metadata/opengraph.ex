# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Pleroma.Web.Metadata.Providers.OpenGraph do
  alias Pleroma.Web.Metadata.Providers.Provider
  alias Pleroma.{HTML, Formatter, User}
  alias Pleroma.Web.MediaProxy

  @behaviour Provider

  @impl Provider
  def build_tags(%{activity: activity, user: user}) do
    attachments = build_attachments(activity)

    [
      {:meta,
       [
         property: "og:title",
         content: user_name_string(user)
       ], []},
      {:meta, [property: "og:url", content: activity.data["id"]], []},
      {:meta, [property: "og:description", content: scrub_html_and_truncate(activity)], []}
    ] ++
      if attachments == [] or
           Enum.any?(activity.data["object"]["tag"], fn tag -> tag == "nsfw" end) do
        [
          {:meta, [property: "og:image", content: attachment_url(User.avatar_url(user))], []},
          {:meta, [property: "og:image:width", content: 120], []},
          {:meta, [property: "og:image:height", content: 120], []}
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
        {:meta, [property: "og:image", content: attachment_url(User.avatar_url(user))], []},
        {:meta, [property: "og:image:width", content: 120], []},
        {:meta, [property: "og:image:height", content: 120], []}
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

          if media_type do
            [
              {:meta, [property: "og:" <> media_type, content: attachment_url(url["href"])], []}
              | acc
            ]
          else
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
