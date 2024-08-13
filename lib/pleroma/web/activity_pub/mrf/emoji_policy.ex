# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.EmojiPolicy do
  require Pleroma.Constants

  alias Pleroma.Object.Updater
  alias Pleroma.Web.ActivityPub.MRF.Utils

  @moduledoc "Reject or force-unlisted emojis with certain URLs or names"

  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  defp config_remove_url do
    Pleroma.Config.get([:mrf_emoji, :remove_url], [])
  end

  defp config_remove_shortcode do
    Pleroma.Config.get([:mrf_emoji, :remove_shortcode], [])
  end

  defp config_unlist_url do
    Pleroma.Config.get([:mrf_emoji, :federated_timeline_removal_url], [])
  end

  defp config_unlist_shortcode do
    Pleroma.Config.get([:mrf_emoji, :federated_timeline_removal_shortcode], [])
  end

  @impl true
  def history_awareness, do: :manual

  @impl true
  def filter(%{"type" => type, "object" => %{"type" => objtype} = object} = activity)
      when type in ["Create", "Update"] and objtype in Pleroma.Constants.status_object_types() do
    with {:ok, object} <-
           Updater.do_with_history(object, fn object ->
             {:ok, process_remove(object, :url, config_remove_url())}
           end),
         {:ok, object} <-
           Updater.do_with_history(object, fn object ->
             {:ok, process_remove(object, :shortcode, config_remove_shortcode())}
           end),
         activity <- Map.put(activity, "object", object),
         activity <- maybe_delist(activity) do
      {:ok, activity}
    end
  end

  @impl true
  def filter(%{"type" => type} = object) when type in Pleroma.Constants.actor_types() do
    with object <- process_remove(object, :url, config_remove_url()),
         object <- process_remove(object, :shortcode, config_remove_shortcode()) do
      {:ok, object}
    end
  end

  @impl true
  def filter(%{"type" => "EmojiReact"} = object) do
    with {:ok, _} <-
           matched_emoji_checker(config_remove_url(), config_remove_shortcode()).(object) do
      {:ok, object}
    else
      _ ->
        {:reject, "[EmojiPolicy] Rejected for having disallowed emoji"}
    end
  end

  @impl true
  def filter(activity) do
    {:ok, activity}
  end

  defp match_string?(string, pattern) when is_binary(pattern) do
    string == pattern
  end

  defp match_string?(string, %Regex{} = pattern) do
    String.match?(string, pattern)
  end

  defp match_any?(string, patterns) do
    Enum.any?(patterns, &match_string?(string, &1))
  end

  defp url_from_tag(%{"icon" => %{"url" => url}}), do: url
  defp url_from_tag(_), do: nil

  defp url_from_emoji({_name, url}), do: url

  defp shortcode_from_tag(%{"name" => name}) when is_binary(name), do: String.trim(name, ":")
  defp shortcode_from_tag(_), do: nil

  defp shortcode_from_emoji({name, _url}), do: name

  defp process_remove(object, :url, patterns) do
    process_remove_impl(object, &url_from_tag/1, &url_from_emoji/1, patterns)
  end

  defp process_remove(object, :shortcode, patterns) do
    process_remove_impl(object, &shortcode_from_tag/1, &shortcode_from_emoji/1, patterns)
  end

  defp process_remove_impl(object, extract_from_tag, extract_from_emoji, patterns) do
    object =
      if object["tag"] do
        Map.put(
          object,
          "tag",
          Enum.filter(
            object["tag"],
            fn
              %{"type" => "Emoji"} = tag ->
                str = extract_from_tag.(tag)

                if is_binary(str) do
                  not match_any?(str, patterns)
                else
                  true
                end

              _ ->
                true
            end
          )
        )
      else
        object
      end

    object =
      if object["emoji"] do
        Map.put(
          object,
          "emoji",
          object["emoji"]
          |> Enum.reduce(%{}, fn {name, url} = emoji, acc ->
            if not match_any?(extract_from_emoji.(emoji), patterns) do
              Map.put(acc, name, url)
            else
              acc
            end
          end)
        )
      else
        object
      end

    object
  end

  defp matched_emoji_checker(urls, shortcodes) do
    fn object ->
      if any_emoji_match?(object, &url_from_tag/1, &url_from_emoji/1, urls) or
           any_emoji_match?(
             object,
             &shortcode_from_tag/1,
             &shortcode_from_emoji/1,
             shortcodes
           ) do
        {:matched, nil}
      else
        {:ok, %{}}
      end
    end
  end

  defp maybe_delist(%{"object" => object, "to" => to, "type" => "Create"} = activity) do
    check = matched_emoji_checker(config_unlist_url(), config_unlist_shortcode())

    should_delist? = fn object ->
      with {:ok, _} <- Pleroma.Object.Updater.do_with_history(object, check) do
        false
      else
        _ -> true
      end
    end

    if Pleroma.Constants.as_public() in to and should_delist?.(object) do
      to = List.delete(to, Pleroma.Constants.as_public())
      cc = [Pleroma.Constants.as_public() | activity["cc"] || []]

      activity
      |> Map.put("to", to)
      |> Map.put("cc", cc)
    else
      activity
    end
  end

  defp maybe_delist(activity), do: activity

  defp any_emoji_match?(object, extract_from_tag, extract_from_emoji, patterns) do
    Kernel.||(
      Enum.any?(
        object["tag"] || [],
        fn
          %{"type" => "Emoji"} = tag ->
            str = extract_from_tag.(tag)

            if is_binary(str) do
              match_any?(str, patterns)
            else
              false
            end

          _ ->
            false
        end
      ),
      (object["emoji"] || [])
      |> Enum.any?(fn emoji -> match_any?(extract_from_emoji.(emoji), patterns) end)
    )
  end

  @impl true
  def describe do
    mrf_emoji =
      Pleroma.Config.get(:mrf_emoji, [])
      |> Enum.map(fn {key, value} ->
        {key, Enum.map(value, &Utils.describe_regex_or_string/1)}
      end)
      |> Enum.into(%{})

    {:ok, %{mrf_emoji: mrf_emoji}}
  end

  @impl true
  def config_description do
    %{
      key: :mrf_emoji,
      related_policy: "Pleroma.Web.ActivityPub.MRF.EmojiPolicy",
      label: "MRF Emoji",
      description:
        "Reject or force-unlisted emojis whose URLs or names match a keyword or [Regex](https://hexdocs.pm/elixir/Regex.html).",
      children: [
        %{
          key: :remove_url,
          type: {:list, :string},
          description: """
            A list of patterns which result in emoji whose URL matches being removed from the activity. This will apply to statuses, emoji reactions, and user profiles.

            Each pattern can be a string or [Regex](https://hexdocs.pm/elixir/Regex.html) in the format of `~r/PATTERN/`.
          """,
          suggestions: ["https://example.org/foo.png", ~r/example.org\/foo/iu]
        },
        %{
          key: :remove_shortcode,
          type: {:list, :string},
          description: """
            A list of patterns which result in emoji whose shortcode matches being removed from the activity. This will apply to statuses, emoji reactions, and user profiles.

            Each pattern can be a string or [Regex](https://hexdocs.pm/elixir/Regex.html) in the format of `~r/PATTERN/`.
          """,
          suggestions: ["foo", ~r/foo/iu]
        },
        %{
          key: :federated_timeline_removal_url,
          type: {:list, :string},
          description: """
            A list of patterns which result in activity with emojis whose URLs match being removed from federated timelines (a.k.a unlisted). This will apply only to statuses.

            Each pattern can be a string or [Regex](https://hexdocs.pm/elixir/Regex.html) in the format of `~r/PATTERN/`.
          """,
          suggestions: ["https://example.org/foo.png", ~r/example.org\/foo/iu]
        },
        %{
          key: :federated_timeline_removal_shortcode,
          type: {:list, :string},
          description: """
            A list of patterns which result in activities with emojis whose shortcodes match being removed from federated timelines (a.k.a unlisted). This will apply only to statuses.

            Each pattern can be a string or [Regex](https://hexdocs.pm/elixir/Regex.html) in the format of `~r/PATTERN/`.
          """,
          suggestions: ["foo", ~r/foo/iu]
        }
      ]
    }
  end
end
