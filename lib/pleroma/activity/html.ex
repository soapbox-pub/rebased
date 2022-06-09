# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Activity.HTML do
  alias Pleroma.HTML
  alias Pleroma.Object

  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)

  # We store a list of cache keys related to an activity in a
  # separate cache, scrubber_management_cache. It has the same
  # size as scrubber_cache (see application.ex). Every time we add
  # a cache to scrubber_cache, we update scrubber_management_cache.
  #
  # The most recent write of a certain key in the management cache
  # is the same as the most recent write of any record related to that
  # key in the main cache.
  # Assuming LRW ( https://hexdocs.pm/cachex/Cachex.Policy.LRW.html ),
  # this means when the management cache is evicted by cachex, all
  # related records in the main cache will also have been evicted.

  defp get_cache_keys_for(activity_id) do
    with {:ok, list} when is_list(list) <- @cachex.get(:scrubber_management_cache, activity_id) do
      list
    else
      _ -> []
    end
  end

  defp add_cache_key_for(activity_id, additional_key) do
    current = get_cache_keys_for(activity_id)

    unless additional_key in current do
      @cachex.put(:scrubber_management_cache, activity_id, [additional_key | current])
    end
  end

  def invalidate_cache_for(activity_id) do
    keys = get_cache_keys_for(activity_id)
    Enum.map(keys, &@cachex.del(:scrubber_cache, &1))
    @cachex.del(:scrubber_management_cache, activity_id)
  end

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

      add_cache_key_for(activity.id, key)
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
