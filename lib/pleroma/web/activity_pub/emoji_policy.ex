# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.EmojiPolicy do
  require Pleroma.Constants

  @moduledoc "Reject or force-unlisted emojis with certain URLs or names"

  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  defp config_remove_url do
    Pleroma.Config.get([:mrf_emoji, :remove_url], [])
  end

  defp config_remove_shortcode do
    Pleroma.Config.get([:mrf_emoji, :remove_shortcode], [])
  end

  @impl Pleroma.Web.ActivityPub.MRF.Policy
  def filter(%{"type" => type, "object" => %{} = object} = message)
      when type in ["Create", "Update"] do
    with object <- process_remove(object, :url, config_remove_url()),
         object <- process_remove(object, :shortcode, config_remove_shortcode()) do
      {:ok, Map.put(message, "object", object)}
    end
  end

  @impl Pleroma.Web.ActivityPub.MRF.Policy
  def filter(%{"type" => type} = object) when type in Pleroma.Constants.actor_types() do
    with object <- process_remove(object, :url, config_remove_url()),
         object <- process_remove(object, :shortcode, config_remove_shortcode()) do
      {:ok, object}
    end
  end

  @impl Pleroma.Web.ActivityPub.MRF.Policy
  def filter(message) do
    {:ok, message}
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

  defp process_remove(object, :url, patterns) do
    process_remove_impl(
      object,
      fn
        %{"icon" => %{"url" => url}} -> url
        _ -> nil
      end,
      fn {_name, url} -> url end,
      patterns
    )
  end

  defp process_remove(object, :shortcode, patterns) do
    process_remove_impl(
      object,
      fn
        %{"name" => name} when is_binary(name) -> String.trim(name, ":")
        _ -> nil
      end,
      fn {name, _url} -> name end,
      patterns
    )
  end

  defp process_remove_impl(object, extract_from_tag, extract_from_emoji, patterns) do
    processed_tag =
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

    processed_emoji =
      if object["emoji"] do
        object["emoji"]
        |> Enum.reduce(%{}, fn {name, url} = emoji, acc ->
          if not match_any?(extract_from_emoji.(emoji), patterns) do
            Map.put(acc, name, url)
          else
            acc
          end
        end)
      else
        nil
      end

    if processed_emoji do
      object
      |> Map.put("tag", processed_tag)
      |> Map.put("emoji", processed_emoji)
    else
      object
      |> Map.put("tag", processed_tag)
    end
  end

  @impl Pleroma.Web.ActivityPub.MRF.Policy
  def describe do
    # This horror is needed to convert regex sigils to strings
    mrf_emoji =
      Pleroma.Config.get(:mrf_emoji, [])
      |> Enum.map(fn {key, value} ->
        {key,
         Enum.map(value, fn
           pattern ->
             if not is_binary(pattern) do
               inspect(pattern)
             else
               pattern
             end
         end)}
      end)
      |> Enum.into(%{})

    {:ok, %{mrf_emoji: mrf_emoji}}
  end

  @impl Pleroma.Web.ActivityPub.MRF.Policy
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
            A list of patterns which result in emoji whose URL matches being removed from the message. This will apply to both statuses and user profiles.

            Each pattern can be a string or [Regex](https://hexdocs.pm/elixir/Regex.html) in the format of `~r/PATTERN/`.
          """,
          suggestions: ["foo", ~r/foo/iu]
        },
        %{
          key: :remove_shortcode,
          type: {:list, :string},
          description: """
            A list of patterns which result in emoji whose shortcode matches being removed from the message. This will apply to both statuses and user profiles.

            Each pattern can be a string or [Regex](https://hexdocs.pm/elixir/Regex.html) in the format of `~r/PATTERN/`.
          """,
          suggestions: ["foo", ~r/foo/iu]
        },
        %{
          key: :federated_timeline_removal_url,
          type: {:list, :string},
          description: """
            A list of patterns which result in message with emojis whose URLs match being removed from federated timelines (a.k.a unlisted). This will apply only to statuses.

            Each pattern can be a string or [Regex](https://hexdocs.pm/elixir/Regex.html) in the format of `~r/PATTERN/`.
          """,
          suggestions: ["foo", ~r/foo/iu]
        },
        %{
          key: :federated_timeline_removal_shortcode,
          type: {:list, :string},
          description: """
            A list of patterns which result in message with emojis whose shortcodes match being removed from federated timelines (a.k.a unlisted). This will apply only to statuses.

            Each pattern can be a string or [Regex](https://hexdocs.pm/elixir/Regex.html) in the format of `~r/PATTERN/`.
          """,
          suggestions: ["foo", ~r/foo/iu]
        }
      ]
    }
  end
end
