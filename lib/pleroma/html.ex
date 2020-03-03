# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTML do
  # Scrubbers are compiled on boot so they can be configured in OTP releases
  #  @on_load :compile_scrubbers

  def compile_scrubbers do
    dir = Path.join(:code.priv_dir(:pleroma), "scrubbers")

    dir
    |> Pleroma.Utils.compile_dir()
    |> case do
      {:error, _errors, _warnings} ->
        raise "Compiling scrubbers failed"

      {:ok, _modules, _warnings} ->
        :ok
    end
  end

  defp get_scrubbers(scrubber) when is_atom(scrubber), do: [scrubber]
  defp get_scrubbers(scrubbers) when is_list(scrubbers), do: scrubbers
  defp get_scrubbers(_), do: [Pleroma.HTML.Scrubber.Default]

  def get_scrubbers do
    Pleroma.Config.get([:markup, :scrub_policy])
    |> get_scrubbers
  end

  def filter_tags(html, nil) do
    filter_tags(html, get_scrubbers())
  end

  def filter_tags(html, scrubbers) when is_list(scrubbers) do
    Enum.reduce(scrubbers, html, fn scrubber, html ->
      filter_tags(html, scrubber)
    end)
  end

  def filter_tags(html, scrubber) do
    {:ok, content} = FastSanitize.Sanitizer.scrub(html, scrubber)
    content
  end

  def filter_tags(html), do: filter_tags(html, nil)
  def strip_tags(html), do: filter_tags(html, FastSanitize.Sanitizer.StripTags)

  def get_cached_scrubbed_html_for_activity(
        content,
        scrubbers,
        activity,
        key \\ "",
        callback \\ fn x -> x end
      ) do
    key = "#{key}#{generate_scrubber_signature(scrubbers)}|#{activity.id}"

    Cachex.fetch!(:scrubber_cache, key, fn _key ->
      object = Pleroma.Object.normalize(activity)
      ensure_scrubbed_html(content, scrubbers, object.data["fake"] || false, callback)
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

  def ensure_scrubbed_html(
        content,
        scrubbers,
        fake,
        callback
      ) do
    content =
      content
      |> filter_tags(scrubbers)
      |> callback.()

    if fake do
      {:ignore, content}
    else
      {:commit, content}
    end
  end

  defp generate_scrubber_signature(scrubber) when is_atom(scrubber) do
    generate_scrubber_signature([scrubber])
  end

  defp generate_scrubber_signature(scrubbers) do
    Enum.reduce(scrubbers, "", fn scrubber, signature ->
      "#{signature}#{to_string(scrubber)}"
    end)
  end

  def extract_first_external_url(_, nil), do: {:error, "No content"}

  def extract_first_external_url(object, content) do
    key = "URL|#{object.id}"

    Cachex.fetch!(:scrubber_cache, key, fn _key ->
      result =
        content
        |> Floki.parse_fragment!()
        |> Floki.filter_out("a.mention,a.hashtag,a[rel~=\"tag\"]")
        |> Floki.attribute("a", "href")
        |> Enum.at(0)

      {:commit, {:ok, result}}
    end)
  end
end
