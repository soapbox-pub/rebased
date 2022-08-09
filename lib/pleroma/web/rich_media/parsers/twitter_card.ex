# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parsers.TwitterCard do
  alias Pleroma.Web.RichMedia.Parser.MetaTags

  @spec parse(Floki.html_tree(), map()) :: map()
  def parse(html, data) do
    data
    |> Map.put(:title, get_page_title(html))
    |> Map.put(:meta, MetaTags.parse(html))
  end

  def get_page_title(html) do
    with [node | _] <- Floki.find(html, "html head title"),
         title when is_binary(title) and title != "" <- Floki.text(node),
         true <- String.valid?(title) do
      title
    else
      _ -> nil
    end
  end
end
