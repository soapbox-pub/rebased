# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.NormalizeMarkup do
  @moduledoc "Scrub configured hypertext markup"
  alias Pleroma.HTML

  @behaviour Pleroma.Web.ActivityPub.MRF

  def filter(%{"type" => activity_type} = object) when activity_type == "Create" do
    scrub_policy = Pleroma.Config.get([:mrf_normalize_markup, :scrub_policy])

    child = object["object"]

    content =
      child["content"]
      |> HTML.filter_tags(scrub_policy)

    child = Map.put(child, "content", content)

    object = Map.put(object, "object", child)

    {:ok, object}
  end

  def filter(object), do: {:ok, object}
end
