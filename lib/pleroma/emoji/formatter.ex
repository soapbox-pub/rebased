# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emoji.Formatter do
  alias Pleroma.Emoji
  alias Pleroma.HTML
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.MediaProxy

  def emojify(text) do
    emojify(text, Emoji.get_all())
  end

  def emojify(text, nil), do: text

  def emojify(text, emoji, strip \\ false) do
    Enum.reduce(emoji, text, fn
      {_, %Emoji{safe_code: emoji, safe_file: file}}, text ->
        String.replace(text, ":#{emoji}:", prepare_emoji_html(emoji, file, strip))

      {unsafe_emoji, unsafe_file}, text ->
        emoji = HTML.strip_tags(unsafe_emoji)
        file = HTML.strip_tags(unsafe_file)
        String.replace(text, ":#{emoji}:", prepare_emoji_html(emoji, file, strip))
    end)
    |> HTML.filter_tags()
  end

  defp prepare_emoji_html(_emoji, _file, true), do: ""

  defp prepare_emoji_html(emoji, file, _strip) do
    "<img class='emoji' alt='#{emoji}' title='#{emoji}' src='#{MediaProxy.url(file)}' />"
  end

  def demojify(text) do
    emojify(text, Emoji.get_all(), true)
  end

  def demojify(text, nil), do: text

  @doc "Outputs a list of the emoji-Maps in a text"
  def get_emoji_map(text) when is_binary(text) do
    Emoji.get_all()
    |> Enum.filter(fn {emoji, %Emoji{}} -> String.contains?(text, ":#{emoji}:") end)
    |> Enum.reduce(%{}, fn {name, %Emoji{file: file}}, acc ->
      Map.put(acc, name, to_string(URI.merge(Endpoint.url(), file)))
    end)
  end

  def get_emoji_map(_), do: %{}
end
