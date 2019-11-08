# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Formatter do
  alias Pleroma.HTML
  alias Pleroma.User

  @safe_mention_regex ~r/^(\s*(?<mentions>(@.+?\s+){1,})+)(?<rest>.*)/s
  @link_regex ~r"((?:http(s)?:\/\/)?[\w.-]+(?:\.[\w\.-]+)+[\w\-\._~%:/?#[\]@!\$&'\(\)\*\+,;=.]+)|[0-9a-z+\-\.]+:[0-9a-z$-_.+!*'(),]+"ui
  @markdown_characters_regex ~r/(`|\*|_|{|}|[|]|\(|\)|#|\+|-|\.|!)/

  @auto_linker_config hashtag: true,
                      hashtag_handler: &Pleroma.Formatter.hashtag_handler/4,
                      mention: true,
                      mention_handler: &Pleroma.Formatter.mention_handler/4

  def escape_mention_handler("@" <> nickname = mention, buffer, _, _) do
    case User.get_cached_by_nickname(nickname) do
      %User{} ->
        # escape markdown characters with `\\`
        # (we don't want something like @user__name to be parsed by markdown)
        String.replace(mention, @markdown_characters_regex, "\\\\\\1")

      _ ->
        buffer
    end
  end

  def mention_handler("@" <> nickname, buffer, opts, acc) do
    case User.get_cached_by_nickname(nickname) do
      %User{id: id} = user ->
        ap_id = get_ap_id(user)
        nickname_text = get_nickname_text(nickname, opts)

        link =
          ~s(<span class="h-card"><a data-user="#{id}" class="u-url mention" href="#{ap_id}" rel="ugc">@<span>#{
            nickname_text
          }</span></a></span>)

        {link, %{acc | mentions: MapSet.put(acc.mentions, {"@" <> nickname, user})}}

      _ ->
        {buffer, acc}
    end
  end

  def hashtag_handler("#" <> tag = tag_text, _buffer, _opts, acc) do
    tag = String.downcase(tag)
    url = "#{Pleroma.Web.base_url()}/tag/#{tag}"
    link = ~s(<a class="hashtag" data-tag="#{tag}" href="#{url}" rel="tag ugc">#{tag_text}</a>)

    {link, %{acc | tags: MapSet.put(acc.tags, {tag_text, tag})}}
  end

  @doc """
  Parses a text and replace plain text links with HTML. Returns a tuple with a result text, mentions, and hashtags.

  If the 'safe_mention' option is given, only consecutive mentions at the start the post are actually mentioned.
  """
  @spec linkify(String.t(), keyword()) ::
          {String.t(), [{String.t(), User.t()}], [{String.t(), String.t()}]}
  def linkify(text, options \\ []) do
    options = options ++ @auto_linker_config

    if options[:safe_mention] && Regex.named_captures(@safe_mention_regex, text) do
      %{"mentions" => mentions, "rest" => rest} = Regex.named_captures(@safe_mention_regex, text)
      acc = %{mentions: MapSet.new(), tags: MapSet.new()}

      {text_mentions, %{mentions: mentions}} = AutoLinker.link_map(mentions, acc, options)
      {text_rest, %{tags: tags}} = AutoLinker.link_map(rest, acc, options)

      {text_mentions <> text_rest, MapSet.to_list(mentions), MapSet.to_list(tags)}
    else
      acc = %{mentions: MapSet.new(), tags: MapSet.new()}
      {text, %{mentions: mentions, tags: tags}} = AutoLinker.link_map(text, acc, options)

      {text, MapSet.to_list(mentions), MapSet.to_list(tags)}
    end
  end

  @doc """
  Escapes a special characters in mention names.
  """
  def mentions_escape(text, options \\ []) do
    options =
      Keyword.merge(options,
        mention: true,
        url: false,
        mention_handler: &Pleroma.Formatter.escape_mention_handler/4
      )

    if options[:safe_mention] && Regex.named_captures(@safe_mention_regex, text) do
      %{"mentions" => mentions, "rest" => rest} = Regex.named_captures(@safe_mention_regex, text)
      AutoLinker.link(mentions, options) <> AutoLinker.link(rest, options)
    else
      AutoLinker.link(text, options)
    end
  end

  def html_escape({text, mentions, hashtags}, type) do
    {html_escape(text, type), mentions, hashtags}
  end

  def html_escape(text, "text/html") do
    HTML.filter_tags(text)
  end

  def html_escape(text, "text/plain") do
    Regex.split(@link_regex, text, include_captures: true)
    |> Enum.map_every(2, fn chunk ->
      {:safe, part} = Phoenix.HTML.html_escape(chunk)
      part
    end)
    |> Enum.join("")
  end

  def truncate(text, max_length \\ 200, omission \\ "...") do
    # Remove trailing whitespace
    text = Regex.replace(~r/([^ \t\r\n])([ \t]+$)/u, text, "\\g{1}")

    if String.length(text) < max_length do
      text
    else
      length_with_omission = max_length - String.length(omission)
      String.slice(text, 0, length_with_omission) <> omission
    end
  end

  defp get_ap_id(%User{source_data: %{"url" => url}}) when is_binary(url), do: url
  defp get_ap_id(%User{ap_id: ap_id}), do: ap_id

  defp get_nickname_text(nickname, %{mentions_format: :full}), do: User.full_nickname(nickname)
  defp get_nickname_text(nickname, _), do: User.local_nickname(nickname)
end
