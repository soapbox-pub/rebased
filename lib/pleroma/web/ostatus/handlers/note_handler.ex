# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OStatus.NoteHandler do
  require Logger
  require Pleroma.Constants

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Federator
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.XML

  @doc """
  Get the context for this note. Uses this:
  1. The context of the parent activity
  2. The conversation reference in the ostatus xml
  3. A newly generated context id.
  """
  def get_context(entry, in_reply_to) do
    context =
      (XML.string_from_xpath("//ostatus:conversation[1]", entry) ||
         XML.string_from_xpath("//ostatus:conversation[1]/@ref", entry) || "")
      |> String.trim()

    with %{data: %{"context" => context}} <- Object.get_cached_by_ap_id(in_reply_to) do
      context
    else
      _e ->
        if String.length(context) > 0 do
          context
        else
          Utils.generate_context_id()
        end
    end
  end

  def get_people_mentions(entry) do
    :xmerl_xpath.string(
      '//link[@rel="mentioned" and @ostatus:object-type="http://activitystrea.ms/schema/1.0/person"]',
      entry
    )
    |> Enum.map(fn person -> XML.string_from_xpath("@href", person) end)
  end

  def get_collection_mentions(entry) do
    transmogrify = fn
      "http://activityschema.org/collection/public" ->
        Pleroma.Constants.as_public()

      group ->
        group
    end

    :xmerl_xpath.string(
      '//link[@rel="mentioned" and @ostatus:object-type="http://activitystrea.ms/schema/1.0/collection"]',
      entry
    )
    |> Enum.map(fn collection -> XML.string_from_xpath("@href", collection) |> transmogrify.() end)
  end

  def get_mentions(entry) do
    (get_people_mentions(entry) ++ get_collection_mentions(entry))
    |> Enum.filter(& &1)
  end

  def get_emoji(entry) do
    try do
      :xmerl_xpath.string('//link[@rel="emoji"]', entry)
      |> Enum.reduce(%{}, fn emoji, acc ->
        Map.put(acc, XML.string_from_xpath("@name", emoji), XML.string_from_xpath("@href", emoji))
      end)
    rescue
      _e -> nil
    end
  end

  def make_to_list(actor, mentions) do
    [
      actor.follower_address
    ] ++ mentions
  end

  def add_external_url(note, entry) do
    url = XML.string_from_xpath("//link[@rel='alternate' and @type='text/html']/@href", entry)
    Map.put(note, "external_url", url)
  end

  def fetch_replied_to_activity(entry, in_reply_to, options \\ []) do
    with %Activity{} = activity <- Activity.get_create_by_object_ap_id(in_reply_to) do
      activity
    else
      _e ->
        with true <- Federator.allowed_incoming_reply_depth?(options[:depth]),
             in_reply_to_href when not is_nil(in_reply_to_href) <-
               XML.string_from_xpath("//thr:in-reply-to[1]/@href", entry),
             {:ok, [activity | _]} <- OStatus.fetch_activity_from_url(in_reply_to_href, options) do
          activity
        else
          _e -> nil
        end
    end
  end

  # TODO: Clean this up a bit.
  def handle_note(entry, doc \\ nil, options \\ []) do
    with id <- XML.string_from_xpath("//id", entry),
         activity when is_nil(activity) <- Activity.get_create_by_object_ap_id_with_object(id),
         [author] <- :xmerl_xpath.string('//author[1]', doc),
         {:ok, actor} <- OStatus.find_make_or_update_user(author),
         content_html <- OStatus.get_content(entry),
         cw <- OStatus.get_cw(entry),
         in_reply_to <- XML.string_from_xpath("//thr:in-reply-to[1]/@ref", entry),
         options <- Keyword.put(options, :depth, (options[:depth] || 0) + 1),
         in_reply_to_activity <- fetch_replied_to_activity(entry, in_reply_to, options),
         in_reply_to_object <-
           (in_reply_to_activity && Object.normalize(in_reply_to_activity)) || nil,
         in_reply_to <- (in_reply_to_object && in_reply_to_object.data["id"]) || in_reply_to,
         attachments <- OStatus.get_attachments(entry),
         context <- get_context(entry, in_reply_to),
         tags <- OStatus.get_tags(entry),
         mentions <- get_mentions(entry),
         to <- make_to_list(actor, mentions),
         date <- XML.string_from_xpath("//published", entry),
         unlisted <- XML.string_from_xpath("//mastodon:scope", entry) == "unlisted",
         cc <- if(unlisted, do: [Pleroma.Constants.as_public()], else: []),
         note <-
           CommonAPI.Utils.make_note_data(
             actor.ap_id,
             to,
             context,
             content_html,
             attachments,
             in_reply_to_activity,
             [],
             cw
           ),
         note <- note |> Map.put("id", id) |> Map.put("tag", tags),
         note <- note |> Map.put("published", date),
         note <- note |> Map.put("emoji", get_emoji(entry)),
         note <- add_external_url(note, entry),
         note <- note |> Map.put("cc", cc),
         # TODO: Handle this case in make_note_data
         note <-
           if(
             in_reply_to && !in_reply_to_activity,
             do: note |> Map.put("inReplyTo", in_reply_to),
             else: note
           ) do
      ActivityPub.create(%{
        to: to,
        actor: actor,
        context: context,
        object: note,
        published: date,
        local: false,
        additional: %{"cc" => cc}
      })
    else
      %Activity{} = activity -> {:ok, activity}
      e -> {:error, e}
    end
  end
end
