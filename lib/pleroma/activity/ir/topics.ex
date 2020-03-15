# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Activity.Ir.Topics do
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.Visibility

  def get_activity_topics(activity) do
    activity
    |> Object.normalize()
    |> generate_topics(activity)
    |> List.flatten()
  end

  defp generate_topics(%{data: %{"type" => "Answer"}}, _) do
    []
  end

  defp generate_topics(object, activity) do
    ["user", "list"] ++ visibility_tags(object, activity)
  end

  defp visibility_tags(object, activity) do
    case Visibility.get_visibility(activity) do
      "public" ->
        if activity.local do
          ["public", "public:local"]
        else
          ["public"]
        end
        |> item_creation_tags(object, activity)

      "direct" ->
        ["direct"]

      _ ->
        []
    end
  end

  defp item_creation_tags(tags, object, %{data: %{"type" => "Create"}} = activity) do
    tags ++ hashtags_to_topics(object) ++ attachment_topics(object, activity)
  end

  defp item_creation_tags(tags, _, _) do
    tags
  end

  defp hashtags_to_topics(%{data: %{"tag" => tags}}) do
    tags
    |> Enum.filter(&is_bitstring(&1))
    |> Enum.map(fn tag -> "hashtag:" <> tag end)
  end

  defp hashtags_to_topics(_), do: []

  defp attachment_topics(%{data: %{"attachment" => []}}, _act), do: []

  defp attachment_topics(_object, %{local: true}), do: ["public:media", "public:local:media"]

  defp attachment_topics(_object, _act), do: ["public:media"]
end
