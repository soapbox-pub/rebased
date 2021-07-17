# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Activity.HTML do
  alias Pleroma.HTML
  alias Pleroma.Object

  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)

  def get_cached_scrubbed_html_for_activity(
        content,
        scrubbers,
        activity,
        key \\ "",
        callback \\ fn x -> x end
      ) do
    key = "#{key}#{generate_scrubber_signature(scrubbers)}|#{activity.id}"

    @cachex.fetch!(:scrubber_cache, key, fn _key ->
      object = Object.normalize(activity, fetch: false)
      HTML.ensure_scrubbed_html(content, scrubbers, object.data["fake"] || false, callback)
    end)
  end

  def get_cached_stripped_html_for_activity(content, activity, key) do
    get_cached_scrubbed_html_for_activity(
      content,
      FastSanitize.Sanitizer.StripTags,
      activity,
      key,
      &HtmlEntities.decode/1
    )
  end

  defp generate_scrubber_signature(scrubber) when is_atom(scrubber) do
    generate_scrubber_signature([scrubber])
  end

  defp generate_scrubber_signature(scrubbers) do
    Enum.reduce(scrubbers, "", fn scrubber, signature ->
      "#{signature}#{to_string(scrubber)}"
    end)
  end
end
