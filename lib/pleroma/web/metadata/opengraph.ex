defmodule Pleroma.Web.Metadata.Providers.OpenGraph do
  alias Pleroma.Web.Metadata.Providers.Provider
  alias Pleroma.{HTML, Formatter, User}
  alias Pleroma.Web.MediaProxy

  @behaviour Provider

  @impl Provider
  def build_tags(%{activity: activity, user: user}) do
    with truncated_content = scrub_html_and_truncate(activity.data["object"]["content"]) do
      attachments = build_attachments(activity)

      [
        {:meta,
         [
           property: "og:title",
           content: user_name_string(user)
         ], []},
        {:meta, [property: "og:url", content: activity.data["id"]], []},
        {:meta, [property: "og:description", content: truncated_content], []}
      ] ++
        if attachments == [] or Enum.any?(activity.data["object"]["tag"], fn tag -> tag == "nsfw" end) do
          [
            {:meta, [property: "og:image", content: attachment_url(User.avatar_url(user))], []},
            {:meta, [property: "og:image:width", content: 120], []},
            {:meta, [property: "og:image:height", content: 120], []}
          ]
        else
          attachments
        end
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

  defp build_attachments(activity) do
    Enum.reduce(activity.data["object"]["attachment"], [], fn attachment, acc ->
      rendered_tags =
        Enum.map(attachment["url"], fn url ->
          media_type =
            Enum.find(["image", "audio", "video"], fn media_type ->
              String.starts_with?(url["mediaType"], media_type)
            end)

          if media_type do
            {:meta, [property: "og:" <> media_type, content: attachment_url(url["href"])], []}
          else
            nil
          end
        end)

      Enum.reject(rendered_tags, &is_nil/1)
      acc ++ rendered_tags
    end)
  end

  defp scrub_html_and_truncate(content) do
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
