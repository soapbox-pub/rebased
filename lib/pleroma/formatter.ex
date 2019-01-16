# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Formatter do
  alias Pleroma.User
  alias Pleroma.Web.MediaProxy
  alias Pleroma.HTML
  alias Pleroma.Emoji

  @tag_regex ~r/((?<=[^&])|\A)(\#)(\w+)/u
  @markdown_characters_regex ~r/(`|\*|_|{|}|[|]|\(|\)|#|\+|-|\.|!)/

  # Modified from https://www.w3.org/TR/html5/forms.html#valid-e-mail-address
  @mentions_regex ~r/@[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]*@?[a-zA-Z0-9_-](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*/u

  def parse_tags(text, data \\ %{}) do
    Regex.scan(@tag_regex, text)
    |> Enum.map(fn ["#" <> tag = full_tag | _] -> {full_tag, String.downcase(tag)} end)
    |> (fn map ->
          if data["sensitive"] in [true, "True", "true", "1"],
            do: [{"#nsfw", "nsfw"}] ++ map,
            else: map
        end).()
  end

  @doc "Parses mentions text and returns list {nickname, user}."
  @spec parse_mentions(binary()) :: list({binary(), User.t()})
  def parse_mentions(text) do
    Regex.scan(@mentions_regex, text)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.map(fn nickname ->
      with nickname <- String.trim_leading(nickname, "@"),
           do: {"@" <> nickname, User.get_cached_by_nickname(nickname)}
    end)
    |> Enum.filter(fn {_match, user} -> user end)
  end

  def emojify(text) do
    emojify(text, Emoji.get_all())
  end

  def emojify(text, nil), do: text

  def emojify(text, emoji) do
    Enum.reduce(emoji, text, fn {emoji, file}, text ->
      emoji = HTML.strip_tags(emoji)
      file = HTML.strip_tags(file)

      String.replace(
        text,
        ":#{emoji}:",
        "<img height='32px' width='32px' alt='#{emoji}' title='#{emoji}' src='#{
          MediaProxy.url(file)
        }' />"
      )
      |> HTML.filter_tags()
    end)
  end

  def get_emoji(text) when is_binary(text) do
    Enum.filter(Emoji.get_all(), fn {emoji, _} -> String.contains?(text, ":#{emoji}:") end)
  end

  def get_emoji(_), do: []

  @link_regex ~r/[0-9a-z+\-\.]+:[0-9a-z$-_.+!*'(),]+/ui

  @uri_schemes Application.get_env(:pleroma, :uri_schemes, [])
  @valid_schemes Keyword.get(@uri_schemes, :valid_schemes, [])

  # TODO: make it use something other than @link_regex
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

  @doc """
  Escapes a special characters in mention names.
  """
  @spec mentions_escape(String.t(), list({String.t(), any()})) :: String.t()
  def mentions_escape(text, mentions) do
    mentions
    |> Enum.reduce(text, fn {name, _}, acc ->
      escape_name = String.replace(name, @markdown_characters_regex, "\\\\\\1")
      String.replace(acc, name, escape_name)
    end)
  end

  @doc "changes scheme:... urls to html links"
  def add_links({subs, text}) do
    links =
      text
      |> String.split([" ", "\t", "<br>"])
      |> Enum.filter(fn word -> String.starts_with?(word, @valid_schemes) end)
      |> Enum.filter(fn word -> Regex.match?(@link_regex, word) end)
      |> Enum.map(fn url -> {Ecto.UUID.generate(), url} end)
      |> Enum.sort_by(fn {_, url} -> -String.length(url) end)

    uuid_text =
      links
      |> Enum.reduce(text, fn {uuid, url}, acc -> String.replace(acc, url, uuid) end)

    subs =
      subs ++
        Enum.map(links, fn {uuid, url} ->
          {uuid, "<a href=\"#{url}\">#{url}</a>"}
        end)

    {subs, uuid_text}
  end

  @doc "Adds the links to mentioned users"
  def add_user_links({subs, text}, mentions) do
    mentions =
      mentions
      |> Enum.sort_by(fn {name, _} -> -String.length(name) end)
      |> Enum.map(fn {name, user} -> {name, user, Ecto.UUID.generate()} end)

    uuid_text =
      mentions
      |> Enum.reduce(text, fn {match, _user, uuid}, text ->
        String.replace(text, match, uuid)
      end)

    subs =
      subs ++
        Enum.map(mentions, fn {match, %User{id: id, ap_id: ap_id, info: info}, uuid} ->
          ap_id =
            if is_binary(info.source_data["url"]) do
              info.source_data["url"]
            else
              ap_id
            end

          short_match = String.split(match, "@") |> tl() |> hd()

          {uuid,
           "<span class='h-card'><a data-user='#{id}' class='u-url mention' href='#{ap_id}'>@<span>#{
             short_match
           }</span></a></span>"}
        end)

    {subs, uuid_text}
  end

  @doc "Adds the hashtag links"
  def add_hashtag_links({subs, text}, tags) do
    tags =
      tags
      |> Enum.sort_by(fn {name, _} -> -String.length(name) end)
      |> Enum.map(fn {name, short} -> {name, short, Ecto.UUID.generate()} end)

    uuid_text =
      tags
      |> Enum.reduce(text, fn {match, _short, uuid}, text ->
        String.replace(text, ~r/((?<=[^&])|(\A))#{match}/, uuid)
      end)

    subs =
      subs ++
        Enum.map(tags, fn {tag_text, tag, uuid} ->
          url =
            "<a class='hashtag' data-tag='#{tag}' href='#{Pleroma.Web.base_url()}/tag/#{tag}' rel='tag'>#{
              tag_text
            }</a>"

          {uuid, url}
        end)

    {subs, uuid_text}
  end

  def finalize({subs, text}) do
    Enum.reduce(subs, text, fn {uuid, replacement}, result_text ->
      String.replace(result_text, uuid, replacement)
    end)
  end
end
