# Pleroma: A lightweight social networking server
# Copyright _ 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Helpers do
  alias Pleroma.{Activity, Object, HTML}
  alias Pleroma.Web.RichMedia.Parser

  def fetch_data_for_activity(%Activity{} = activity) do
    with true <- Pleroma.Config.get([:rich_media, :enabled], true),
         %Object{} = object <- Object.normalize(activity.data["object"]),
         {:ok, page_url} <- HTML.extract_first_external_url(object, object.data["content"]),
         {:ok, rich_media} <- Parser.parse(page_url) do
      %{page_url: page_url, rich_media: rich_media}
    else
      _ -> %{}
    end
  end
end
