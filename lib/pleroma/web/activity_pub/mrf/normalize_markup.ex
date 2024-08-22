# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.NormalizeMarkup do
  @moduledoc "Scrub configured hypertext markup"
  alias Pleroma.HTML

  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  @impl true
  def history_awareness, do: :auto

  @impl true
  def filter(%{"type" => type, "object" => object} = activity)
      when type in ["Create", "Update"] do
    scrub_policy = Pleroma.Config.get([:mrf_normalize_markup, :scrub_policy])

    content =
      object["content"]
      |> HTML.filter_tags(scrub_policy)

    activity = put_in(activity, ["object", "content"], content)

    {:ok, activity}
  end

  def filter(activity), do: {:ok, activity}

  @impl true
  def describe, do: {:ok, %{}}

  @impl true
  def config_description do
    %{
      key: :mrf_normalize_markup,
      related_policy: "Pleroma.Web.ActivityPub.MRF.NormalizeMarkup",
      label: "MRF Normalize Markup",
      description: "MRF NormalizeMarkup settings. Scrub configured hypertext markup.",
      children: [
        %{
          key: :scrub_policy,
          type: :module,
          suggestions: [Pleroma.HTML.Scrubber.Default]
        }
      ]
    }
  end
end
