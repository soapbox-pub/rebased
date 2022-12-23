# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Utils do
  alias Pleroma.Activity
  alias Pleroma.Emoji
  alias Pleroma.Formatter
  alias Pleroma.HTML

  defp scrub_html_and_truncate_object_field(field, object) do
    field
    # html content comes from DB already encoded, decode first and scrub after
    |> HtmlEntities.decode()
    |> String.replace(~r/<br\s?\/?>/, " ")
    |> Activity.HTML.get_cached_stripped_html_for_activity(object, "metadata")
    |> Emoji.Formatter.demojify()
    |> HtmlEntities.decode()
    |> Formatter.truncate()
  end

  def scrub_html_and_truncate(%{data: %{"summary" => summary}} = object)
      when is_binary(summary) and summary != "" do
    summary
    |> scrub_html_and_truncate_object_field(object)
  end

  def scrub_html_and_truncate(%{data: %{"content" => content}} = object) do
    content
    |> scrub_html_and_truncate_object_field(object)
  end

  def scrub_html_and_truncate(content, max_length \\ 200) when is_binary(content) do
    content
    |> scrub_html
    |> Emoji.Formatter.demojify()
    |> HtmlEntities.decode()
    |> Formatter.truncate(max_length)
  end

  def scrub_html(content) when is_binary(content) do
    content
    # html content comes from DB already encoded, decode first and scrub after
    |> HtmlEntities.decode()
    |> String.replace(~r/<br\s?\/?>/, " ")
    |> HTML.strip_tags()
  end

  def scrub_html(content), do: content

  def user_name_string(user) do
    "#{user.name} " <>
      if user.local do
        "(@#{user.nickname}@#{Pleroma.Web.Endpoint.host()})"
      else
        "(@#{user.nickname})"
      end
  end

  @spec fetch_media_type(list(String.t()), String.t()) :: String.t() | nil
  def fetch_media_type(supported_types, media_type) do
    Enum.find(supported_types, fn support_type ->
      String.starts_with?(media_type, support_type)
    end)
  end
end
