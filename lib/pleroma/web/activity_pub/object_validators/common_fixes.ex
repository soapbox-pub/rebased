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

  require Pleroma.Constants

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

  def fix_quote_url(%{"quoteUrl" => _quote_url} = data), do: data

  # Fedibird
  # https://github.com/fedibird/mastodon/commit/dbd7ae6cf58a92ec67c512296b4daaea0d01e6ac
  def fix_quote_url(%{"quoteUri" => quote_url} = data) do
    Map.put(data, "quoteUrl", quote_url)
  end

  # Old Fedibird (bug)
  # https://github.com/fedibird/mastodon/issues/9
  def fix_quote_url(%{"quoteURL" => quote_url} = data) do
    Map.put(data, "quoteUrl", quote_url)
  end

  # Misskey fallback
  def fix_quote_url(%{"_misskey_quote" => quote_url} = data) do
    Map.put(data, "quoteUrl", quote_url)
  end

  def fix_quote_url(%{"tag" => [_ | _] = tags} = data) do
    tag = Enum.find(tags, &is_object_link_tag/1)

    if not is_nil(tag) do
      data
      |> Map.put("quoteUrl", tag["href"])
    else
      data
    end
  end

  def fix_quote_url(data), do: data

  # https://codeberg.org/fediverse/fep/src/branch/main/fep/e232/fep-e232.md
  def is_object_link_tag(%{
        "type" => "Link",
        "mediaType" => media_type,
        "href" => href
      })
      when media_type in Pleroma.Constants.activity_json_mime_types() and is_binary(href) do
    true
  end

  def is_object_link_tag(_), do: false
end
