# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Activity.Ir.Topics do
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.Visibility

  def get_activity_topics(activity) do
    activity
    |> Object.normalize(fetch: false)
    |> generate_topics(activity)
    |> List.flatten()
  end

  defp generate_topics(%{data: %{"type" => "ChatMessage"}}, %{data: %{"type" => "Delete"}}) do
    ["user", "user:pleroma_chat"]
  end

  defp generate_topics(%{data: %{"type" => "ChatMessage"}}, %{data: %{"type" => "Create"}}) do
    []
  end

  defp generate_topics(%{data: %{"type" => "Answer"}}, _) do
    []
  end

  defp generate_topics(object, activity) do
    ["user", "list"] ++ visibility_tags(object, activity)
  end

  defp visibility_tags(object, %{data: %{"type" => type}} = activity) when type != "Announce" do
    case Visibility.get_visibility(activity) do
      "public" ->
        if activity.local do
          ["public", "public:local"]
        else
          ["public"]
        end
        |> item_creation_tags(object, activity)

      "local" ->
        ["public:local"]
        |> item_creation_tags(object, activity)

      "direct" ->
        ["direct"]

      _ ->
        []
    end
  end

  defp visibility_tags(_object, _activity) do
    []
  end

  defp item_creation_tags(tags, object, %{data: %{"type" => "Create"}} = activity) do
    tags ++
      remote_topics(activity) ++ hashtags_to_topics(object) ++ attachment_topics(object, activity)
  end

  defp item_creation_tags(tags, _, _) do
    tags
  end

  defp hashtags_to_topics(object) do
    object
    |> Object.hashtags()
    |> Enum.map(fn hashtag -> "hashtag:" <> hashtag end)
  end

  defp remote_topics(%{local: true}), do: []

  defp remote_topics(%{actor: actor}) when is_binary(actor),
    do: ["public:remote:" <> URI.parse(actor).host]

  defp remote_topics(_), do: []

  defp attachment_topics(%{data: %{"attachment" => []}}, _act), do: []

  defp attachment_topics(_object, %{local: true} = activity) do
    case Visibility.get_visibility(activity) do
      "public" ->
        ["public:media", "public:local:media"]

      "local" ->
        ["public:local:media"]

      _ ->
        []
    end
  end

  defp attachment_topics(_object, %{actor: actor}) when is_binary(actor),
    do: ["public:media", "public:remote:media:" <> URI.parse(actor).host]

  defp attachment_topics(_object, _act), do: ["public:media"]
end
