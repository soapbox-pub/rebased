# Pleroma: A lightweight social networking server
# Copyright _ 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI do
  alias Pleroma.{Repo, Activity, Object, HTML}
  alias Pleroma.Web.ActivityPub.ActivityPub

  def get_status_card(status_id) do
    with %Activity{} = activity <- Repo.get(Activity, status_id),
         true <- ActivityPub.is_public?(activity),
         %Object{} = object <- Object.normalize(activity.data["object"]),
         page_url <- HTML.extract_first_external_url(object, object.data["content"]),
         {:ok, rich_media} <- Pleroma.Web.RichMedia.Parser.parse(page_url) do
      %{page_url: page_url, rich_media: rich_media}
    else
      _ -> %{}
    end
  end
end
