defmodule Pleroma.Web.OStatus.NoteHandler do
  require Logger
  alias Pleroma.Web.{XML, OStatus}
  alias Pleroma.{Object, User, Activity}
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI

  @doc """
  Get the context for this note. Uses this:
  1. The context of the parent activity
  2. The conversation reference in the ostatus xml
  3. A newly generated context id.
  """
  def get_context(entry, inReplyTo) do
    context = (
      XML.string_from_xpath("//ostatus:conversation[1]", entry)
      || XML.string_from_xpath("//ostatus:conversation[1]/@ref", entry)
      || "") |> String.trim

    with %{data: %{"context" => context}} <- Object.get_cached_by_ap_id(inReplyTo) do
      context
    else _e ->
      if String.length(context) > 0 do
        context
      else
        Utils.generate_context_id
      end
    end
  end

  def get_people_mentions(entry) do
    :xmerl_xpath.string('//link[@rel="mentioned" and @ostatus:object-type="http://activitystrea.ms/schema/1.0/person"]', entry)
    |> Enum.map(fn(person) -> XML.string_from_xpath("@href", person) end)
  end

  def get_collection_mentions(entry) do
    transmogrify = fn
      ("http://activityschema.org/collection/public") ->
        "https://www.w3.org/ns/activitystreams#Public"
      (group) ->
        group
    end

    :xmerl_xpath.string('//link[@rel="mentioned" and @ostatus:object-type="http://activitystrea.ms/schema/1.0/collection"]', entry)
    |> Enum.map(fn(collection) -> XML.string_from_xpath("@href", collection) |> transmogrify.() end)
  end

  def get_mentions(entry) do
    (get_people_mentions(entry)
      ++ get_collection_mentions(entry))
    |> Enum.filter(&(&1))
  end

  def get_emoji(entry) do
    try do
      :xmerl_xpath.string('//link[@rel="emoji"]', entry)
      |> Enum.reduce(%{}, fn(emoji, acc) ->
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

  def fetch_replied_to_activity(entry, inReplyTo) do
    with %Activity{} = activity <- Activity.get_create_activity_by_object_ap_id(inReplyTo) do
      activity
    else
      _e ->
        with inReplyToHref when not is_nil(inReplyToHref) <- XML.string_from_xpath("//thr:in-reply-to[1]/@href", entry),
             {:ok, [activity | _]} <- OStatus.fetch_activity_from_url(inReplyToHref) do
          activity
        else
          _e -> nil
        end
    end
  end

  def handle_note(entry, doc \\ nil) do
    with id <- XML.string_from_xpath("//id", entry),
         activity when is_nil(activity) <- Activity.get_create_activity_by_object_ap_id(id),
         [author] <- :xmerl_xpath.string('//author[1]', doc),
         {:ok, actor} <- OStatus.find_make_or_update_user(author),
         content_html <- OStatus.get_content(entry),
         cw <- OStatus.get_cw(entry),
         inReplyTo <- XML.string_from_xpath("//thr:in-reply-to[1]/@ref", entry),
         inReplyToActivity <- fetch_replied_to_activity(entry, inReplyTo),
         inReplyTo <- (inReplyToActivity && inReplyToActivity.data["object"]["id"]) || inReplyTo,
         attachments <- OStatus.get_attachments(entry),
         context <- get_context(entry, inReplyTo),
         tags <- OStatus.get_tags(entry),
         mentions <- get_mentions(entry),
         to <- make_to_list(actor, mentions),
         date <- XML.string_from_xpath("//published", entry),
         note <- CommonAPI.Utils.make_note_data(actor.ap_id, to, context, content_html, attachments, inReplyToActivity, [], cw),
         note <- note |> Map.put("id", id) |> Map.put("tag", tags),
         note <- note |> Map.put("published", date),
         note <- note |> Map.put("emoji", get_emoji(entry)),
         note <- add_external_url(note, entry),
         # TODO: Handle this case in make_note_data
         note <- (if inReplyTo && !inReplyToActivity, do: note |> Map.put("inReplyTo", inReplyTo), else: note)
      do
      res = ActivityPub.create(to, actor, context, note, %{}, date, false)
      User.increase_note_count(actor)
      res
    else
      %Activity{} = activity -> {:ok, activity}
      e -> {:error, e}
    end
  end
end
