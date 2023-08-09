# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.NoPlaceholderTextPolicy do
  @moduledoc "Ensure no content placeholder is present (such as the dot from mastodon)"
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  @placeholders [".", "<p>.</p>"]

  @impl true
  def history_awareness, do: :auto

  @impl true
  def filter(
        %{
          "type" => type,
          "object" => %{"contentMap" => %{} = content_map, "attachment" => _} = _child_object
        } = object
      )
      when type in ["Create", "Update"] do
    fixed_content_map =
      Enum.reduce(content_map, %{}, fn {lang, content}, acc ->
        if content in @placeholders do
          acc
        else
          Map.put(acc, lang, content)
        end
      end)

    fixed_object =
      if fixed_content_map == %{} do
        Map.put(
          object,
          "object",
          object["object"]
          |> Map.drop(["contentMap"])
          |> Map.put("content", "")
        )
      else
        object
        |> put_in(["object", "contentMap"], fixed_content_map)
        |> put_in(
          ["object", "content"],
          Pleroma.MultiLanguage.map_to_str(fixed_content_map, multiline: true)
        )
      end

    {:ok, fixed_object}
  end

  @impl true
  def filter(
        %{
          "type" => type,
          "object" => %{"content" => content, "attachment" => _} = _child_object
        } = object
      )
      when type in ["Create", "Update"] and content in @placeholders do
    {:ok, put_in(object, ["object", "content"], "")}
  end

  @impl true
  def filter(object), do: {:ok, object}

  @impl true
  def describe, do: {:ok, %{}}
end
