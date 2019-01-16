defmodule Pleroma.Web.Metadata do
  alias Phoenix.HTML

  @parsers Pleroma.Config.get([:metadata, :providers], [])
  def get_cached_tags(%{activity: activity, user: user} = params) do
    # We don't need to use the both activity and a user since the object can't change it's content
    key = "#{:erlang.term_to_binary(user)}#{activity.data["id"]}"

    Cachex.fetch!(:metadata_cache, key, fn _key ->
      {:commit, build_tags(params)}
    end)
  end

  def get_cached_tags(%{user: user} = params) do
    # I am unsure how well ETS works with big keys
    key = :erlang.term_to_binary(user)

    Cachex.fetch!(:metadata_cache, key, fn _key ->
      {:commit, build_tags(params)}
    end)
  end

  def build_tags(params) do
    Enum.reduce(@parsers, "", fn parser, acc ->
      rendered_html =
        params
        |> parser.build_tags()
        |> Enum.map(&to_tag/1)
        |> Enum.map(&HTML.safe_to_string/1)
        |> Enum.join()

      acc <> rendered_html
    end)
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
end
