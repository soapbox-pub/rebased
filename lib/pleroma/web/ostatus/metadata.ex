defmodule Pleroma.Web.Metadata do
  alias Phoenix.HTML
  alias Pleroma.{Formatter, User}
  alias Pleroma.Web.MediaProxy

  def build_tags(params) do
    if(meta_enabled?(:opengraph), do: opengraph_tags(params), else: [])
    |> Enum.map(&to_tag/1)
    |> Enum.map(&HTML.safe_to_string/1)
    |> Enum.join("\n")
  end

  def meta_enabled?(type) do
    config = Pleroma.Config.get(:metadata, [])
    Keyword.get(config, type, false)
  end

  # opengraph for single status
  defp opengraph_tags(%{activity: activity, user: user}) do
    with truncated_content = Formatter.truncate(activity.data["object"]["content"]) do
      [
        {:meta,
         [
           property: "og:title",
           content: "#{user.name} (@#{user.nickname}@#{pleroma_domain()}) post ##{activity.id}"
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

  # opengraph for user card
  defp opengraph_tags(%{user: user}) do
    with truncated_bio = Formatter.truncate(user.bio) do
      [
        {:meta,
         [
           property: "og:title",
           content: "#{user.name} (@#{user.nickname}@#{pleroma_domain()}) profile"
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

  def to_tag(data) do
    with {name, attrs, _content = []} <- data do
      HTML.Tag.tag(name, attrs)
    else
      {name, attrs, content} ->
        HTML.Tag.content_tag(name, content, attrs)

      _ ->
        raise ArgumentError, message: "make_tag invalid args"
    end
  end

  defp user_avatar_url(user) do
    User.avatar_url(user) |> MediaProxy.url()
  end

  def pleroma_domain do
    Pleroma.Config.get([:instance, :domain], "UNKNOWN_DOMAIN")
  end
end
