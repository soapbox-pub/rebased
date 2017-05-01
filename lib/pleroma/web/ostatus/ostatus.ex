defmodule Pleroma.Web.OStatus do
  import Ecto.Query
  import Pleroma.Web.XML
  require Logger

  alias Pleroma.{Repo, User, Web, Object}
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.{WebFinger, Websub}

  def feed_path(user) do
    "#{user.ap_id}/feed.atom"
  end

  def pubsub_path(user) do
    "#{Web.base_url}/push/hub/#{user.nickname}"
  end

  def salmon_path(user) do
    "#{user.ap_id}/salmon"
  end

  def handle_incoming(xml_string) do
    doc = parse_document(xml_string)
    entries = :xmerl_xpath.string('//entry', doc)

    activities = Enum.map(entries, fn (entry) ->
      {:xmlObj, :string, object_type } = :xmerl_xpath.string('string(/entry/activity:object-type[1])', entry)

      case object_type do
        'http://activitystrea.ms/schema/1.0/note' ->
          with {:ok, activity} <- handle_note(entry, doc), do: activity
        'http://activitystrea.ms/schema/1.0/comment' ->
          with {:ok, activity} <- handle_note(entry, doc), do: activity
        _ ->
          Logger.error("Couldn't parse incoming document")
          nil
      end
    end)
    {:ok, activities}
  end

  def handle_note(entry, doc \\ nil) do
    content_html = string_from_xpath("/entry/content[1]", entry)

    uri = string_from_xpath("/entry/author/uri[1]", entry) || string_from_xpath("/feed/author/uri[1]", doc)
    {:ok, actor} = find_or_make_user(uri)

    context = (string_from_xpath("/entry/ostatus:conversation[1]", entry) || "") |> String.trim
    context = if String.length(context) > 0 do
      context
    else
      ActivityPub.generate_context_id
    end

    to = [
      "https://www.w3.org/ns/activitystreams#Public"
    ]

    mentions = :xmerl_xpath.string('/entry/link[@rel="mentioned" and @ostatus:object-type="http://activitystrea.ms/schema/1.0/person"]', entry)
    |> Enum.map(fn(person) -> string_from_xpath("@href", person) end)

    to = to ++ mentions

    date = string_from_xpath("/entry/published", entry)
    id = string_from_xpath("/entry/id", entry)

    object = %{
      "id" => id,
      "type" => "Note",
      "to" => to,
      "content" => content_html,
      "published" => date,
      "context" => context,
      "actor" => actor.ap_id
    }

    inReplyTo = string_from_xpath("/entry/thr:in-reply-to[1]/@ref", entry)

    object = if inReplyTo do
      Map.put(object, "inReplyTo", inReplyTo)
    else
      object
    end

    # TODO: Bail out sooner and use transaction.
    if Object.get_by_ap_id(id) do
      {:error, "duplicate activity"}
    else
      ActivityPub.create(to, actor, context, object, %{}, date)
    end
  end

  def find_or_make_user(uri) do
    query = from user in User,
      where: user.local == false and fragment("? @> ?", user.info, ^%{uri: uri})

    user = Repo.one(query)

    if is_nil(user) do
      make_user(uri)
    else
      {:ok, user}
    end
  end

  def make_user(uri) do
    with {:ok, info} <- gather_user_info(uri) do
      data = %{
        local: false,
        name: info.name,
        nickname: info.nickname <> "@" <> info.host,
        ap_id: info.uri,
        info: info,
        avatar: info.avatar
      }
      # TODO: Make remote user changeset
      # SHould enforce fqn nickname
      Repo.insert(Ecto.Changeset.change(%User{}, data))
    end
  end

  # TODO: Just takes the first one for now.
  def make_avatar_object(author_doc) do
    href = string_from_xpath("/feed/author[1]/link[@rel=\"avatar\"]/@href", author_doc)
    type = string_from_xpath("/feed/author[1]/link[@rel=\"avatar\"]/@type", author_doc)

    if href do
      %{
        "type" => "Image",
        "url" =>
          [%{
              "type" => "Link",
              "mediaType" => type,
              "href" => href
           }]
      }
    else
      nil
    end
  end

  def gather_user_info(username) do
    with {:ok, webfinger_data} <- WebFinger.finger(username),
         {:ok, feed_data} <- Websub.gather_feed_data(webfinger_data.topic) do
      {:ok, Map.merge(webfinger_data, feed_data) |> Map.put(:fqn, username)}
    else e ->
      Logger.debug("Couldn't gather info for #{username}")
      {:error, e}
    end
  end
end
