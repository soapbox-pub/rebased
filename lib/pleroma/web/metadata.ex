# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata do
  alias Phoenix.HTML

  def build_tags(params) do
    Enum.reduce(Pleroma.Config.get([__MODULE__, :providers], []), "", fn parser, acc ->
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

  def activity_nsfw?(%{data: %{"sensitive" => sensitive}}) do
    Pleroma.Config.get([__MODULE__, :unfurl_nsfw], false) == false and sensitive
  end

  def activity_nsfw?(_) do
    false
  end
end
