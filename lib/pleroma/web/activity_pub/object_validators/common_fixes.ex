# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.CommonFixes do
  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Object
  alias Pleroma.Object.Containment
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.Utils

  import Pleroma.EctoType.ActivityPub.ObjectValidators.LanguageCode,
    only: [is_good_locale_code?: 1]

  import Pleroma.Web.Utils.Guards, only: [not_empty_string: 1]

  def cast_and_filter_recipients(message, field, follower_collection, field_fallback \\ []) do
    {:ok, data} = ObjectValidators.Recipients.cast(message[field] || field_fallback)

    data =
      Enum.reject(data, fn x ->
        String.ends_with?(x, "/followers") and x != follower_collection
      end)

    Map.put(message, field, data)
  end

  def fix_object_defaults(data) do
    context =
      Utils.maybe_create_context(
        data["context"] || data["conversation"] || data["inReplyTo"] || data["id"]
      )

    %User{follower_address: follower_collection} = User.get_cached_by_ap_id(data["attributedTo"])

    data
    |> Map.put("context", context)
    |> cast_and_filter_recipients("to", follower_collection)
    |> cast_and_filter_recipients("cc", follower_collection)
    |> cast_and_filter_recipients("bto", follower_collection)
    |> cast_and_filter_recipients("bcc", follower_collection)
    |> Transmogrifier.fix_implicit_addressing(follower_collection)
  end

  def fix_activity_addressing(activity) do
    %User{follower_address: follower_collection} = User.get_cached_by_ap_id(activity["actor"])

    activity
    |> cast_and_filter_recipients("to", follower_collection)
    |> cast_and_filter_recipients("cc", follower_collection)
    |> cast_and_filter_recipients("bto", follower_collection)
    |> cast_and_filter_recipients("bcc", follower_collection)
    |> Transmogrifier.fix_implicit_addressing(follower_collection)
  end

  def fix_actor(data) do
    actor =
      data
      |> Map.put_new("actor", data["attributedTo"])
      |> Containment.get_actor()

    data
    |> Map.put("actor", actor)
    |> Map.put("attributedTo", actor)
  end

  def fix_activity_context(data, %Object{data: %{"context" => object_context}}) do
    data
    |> Map.put("context", object_context)
  end

  def fix_object_action_recipients(%{"actor" => actor} = data, %Object{data: %{"actor" => actor}}) do
    to = ((data["to"] || []) -- [actor]) |> Enum.uniq()

    Map.put(data, "to", to)
  end

  def fix_object_action_recipients(data, %Object{data: %{"actor" => actor}}) do
    to = ((data["to"] || []) ++ [actor]) |> Enum.uniq()

    Map.put(data, "to", to)
  end

  def maybe_add_language(object, meta \\ []) do
    language =
      [
        get_language_from_context(object),
        get_language_from_context(Keyword.get(meta, :activity_data)),
        get_language_from_content_map(object)
      ]
      |> Enum.find(&is_good_locale_code?(&1))

    if language do
      Map.put(object, "language", language)
    else
      object
    end
  end

  defp get_language_from_context(%{"@context" => context}) when is_list(context) do
    case context
         |> Enum.find(fn
           %{"@language" => language} -> language != "und"
           _ -> nil
         end) do
      %{"@language" => language} -> language
      _ -> nil
    end
  end

  defp get_language_from_context(_), do: nil

  defp get_language_from_content_map(%{"contentMap" => content_map, "content" => source_content}) do
    content_groups = Map.to_list(content_map)

    case Enum.find(content_groups, fn {_, content} -> content == source_content end) do
      {language, _} -> language
      _ -> nil
    end
  end

  defp get_language_from_content_map(_), do: nil

  def maybe_add_content_map(%{"language" => language, "content" => content} = object)
      when not_empty_string(language) do
    Map.put(object, "contentMap", Map.put(%{}, language, content))
  end

  def maybe_add_content_map(object), do: object
end
