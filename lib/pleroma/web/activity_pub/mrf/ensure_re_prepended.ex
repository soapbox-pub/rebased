# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.EnsureRePrepended do
  alias Pleroma.Object

  @moduledoc "Ensure a re: is prepended on replies to a post with a Subject"
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  @reply_prefix Regex.compile!("^re:[[:space:]]*", [:caseless])

  def history_awareness, do: :auto

  def filter_by_summary(
        %{data: %{"summaryMap" => %{} = parent_summary_map}} = _in_reply_to,
        %{"summaryMap" => %{} = child_summary_map} = child
      ) do
    fixed_summary_map =
      Enum.reduce(child_summary_map, %{}, fn {lang, cur}, acc ->
        with {:ok, fixed_cur} <- fix_one(cur, parent_summary_map[lang]) do
          Map.put(acc, lang, fixed_cur)
        else
          _ -> Map.put(acc, lang, cur)
        end
      end)

    child
    |> Map.put("summaryMap", fixed_summary_map)
    |> Map.put("summary", Pleroma.MultiLanguage.map_to_str(fixed_summary_map, multiline: false))
  end

  def filter_by_summary(
        %{data: %{"summary" => parent_summary}} = _in_reply_to,
        %{"summary" => child_summary} = child
      )
      when not is_nil(child_summary) and byte_size(child_summary) > 0 and
             not is_nil(parent_summary) and byte_size(parent_summary) > 0 do
    with {:ok, fixed_child_summary} <- fix_one(child_summary, parent_summary) do
      Map.put(child, "summary", fixed_child_summary)
    else
      _ -> child
    end
  end

  def filter_by_summary(_in_reply_to, child), do: child

  def filter(%{"type" => type, "object" => child_object} = object)
      when type in ["Create", "Update"] and is_map(child_object) do
    child =
      child_object["inReplyTo"]
      |> Object.normalize(fetch: false)
      |> filter_by_summary(child_object)

    object = Map.put(object, "object", child)

    {:ok, object}
  end

  def filter(object), do: {:ok, object}

  def describe, do: {:ok, %{}}

  defp fix_one(child_summary, parent_summary)
       when is_binary(child_summary) and child_summary != "" and is_binary(parent_summary) and
              parent_summary != "" do
    if (child_summary == parent_summary and not Regex.match?(@reply_prefix, child_summary)) or
         (Regex.match?(@reply_prefix, parent_summary) &&
            Regex.replace(@reply_prefix, parent_summary, "") == child_summary) do
      {:ok, "re: " <> child_summary}
    else
      {:nochange, nil}
    end
  end

  defp fix_one(_, _) do
    {:nochange, nil}
  end
end
