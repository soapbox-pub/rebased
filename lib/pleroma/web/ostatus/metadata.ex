defmodule Pleroma.Web.Metadata do
  alias Phoenix.HTML
  alias Pleroma.{Web, Formatter}
  alias Pleroma.{User, Activity}
  alias Pleroma.Web.MediaProxy

  def build_tags(activity, user, url) do
    Enum.concat([
      if(meta_enabled?(:opengraph), do: opengraph_tags(activity, user), else: []),
      if(meta_enabled?(:oembed), do: oembed_links(url), else: [])
    ])
    |> Enum.map(&to_tag/1)
    |> Enum.map(&HTML.safe_to_string/1)
    |> Enum.join("\n")
  end

  def meta_enabled?(type) do
    config = Pleroma.Config.get(:metadata, [])
    Keyword.get(config, type, false)
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

  defp oembed_links(url) do
    Enum.map(["xml", "json"], fn format ->
      href = HTML.raw(oembed_path(url, format))
      { :link, [ type: ["application/#{format}+oembed"], href: href, rel: 'alternate'], [] }
    end)
  end

  defp opengraph_tags(activity, user) do
    with image = User.avatar_url(user) |> MediaProxy.url(),
         truncated_content = Formatter.truncate(activity.data["object"]["content"]),
         domain = Pleroma.Config.get([:instance, :domain], "UNKNOWN_DOMAIN") do
      [
        {:meta,
          [
            property: "og:title",
            content: "#{user.name} (@#{user.nickname}@#{domain}) post ##{activity.id}"
          ], []},
        {:meta, [property: "og:url", content: activity.data["id"]], []},
        {:meta, [property: "og:description", content: truncated_content],
          []},
        {:meta, [property: "og:image", content: image], []},
        {:meta, [property: "og:image:width", content: 120], []},
        {:meta, [property: "og:image:height", content: 120], []},
        {:meta, [property: "twitter:card", content: "summary"], []}
      ]
    end
  end

  defp oembed_path(url, format) do
    query = URI.encode_query(%{url: url, format: format})
    "#{Web.base_url()}/oembed?#{query}"
  end
end