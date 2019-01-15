defmodule Pleroma.Web.Metadata.Providers.OpenGraph do
  alias Pleroma.Web.Metadata.Providers.Provider
  alias Pleroma.{HTML, Formatter, User}
  alias Pleroma.Web.MediaProxy

  @behaviour Provider

  @impl Provider
  def build_tags(%{activity: activity, user: user}) do
    with truncated_content = scrub_html_and_truncate(activity.data["object"]["content"]) do
      [
        {:meta,
         [
           property: "og:title",
           content: user_name_string(user)
         ], []},
        {:meta, [property: "og:url", content: activity.data["id"]], []},
        {:meta, [property: "og:description", content: truncated_content], []},
        {:meta, [property: "og:image", content: user_avatar_url(user)], []},
        {:meta, [property: "og:image:width", content: 120], []},
        {:meta, [property: "og:image:height", content: 120], []},
        {:meta, [property: "twitter:card", content: "summary"], []}
      ]
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
        {:meta, [property: "og:image", content: user_avatar_url(user)], []},
        {:meta, [property: "og:image:width", content: 120], []},
        {:meta, [property: "og:image:height", content: 120], []},
        {:meta, [property: "twitter:card", content: "summary"], []}
      ]
    end
  end

  defp scrub_html_and_truncate(content) do
    content
    # html content comes from DB already encoded, decode first and scrub after
    |> HtmlEntities.decode()
    |> HTML.strip_tags()
    |> Formatter.truncate()
  end

  defp user_avatar_url(user) do
    User.avatar_url(user) |> MediaProxy.url()
  end

  defp user_name_string(user) do
    "#{user.name}" <>
      if user.local do
        "(@#{user.nickname}@#{Pleroma.Web.Endpoint.host()})"
      else
        "(@#{user.nickname})"
      end
  end
end
