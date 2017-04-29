defmodule Pleroma.Web.OStatus do
  import Ecto.Query
  import Pleroma.Web.XML
  require Logger

  alias Pleroma.{Repo, User, Web}
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

    {:xmlObj, :string, object_type } = :xmerl_xpath.string('string(/entry/activity:object-type[1])', doc)

    case object_type do
      'http://activitystrea.ms/schema/1.0/note' ->
        handle_note(doc)
      _ ->
        Logger.error("Couldn't parse incoming document")
    end
  end

  # TODO
  # wire up replies
  def handle_note(doc) do
    content_html = string_from_xpath("/entry/content[1]", doc)

    uri = string_from_xpath("/entry/author/uri[1]", doc)
    {:ok, actor} = find_or_make_user(uri)

    context = string_from_xpath("/entry/ostatus:conversation[1]", doc) |> String.trim
    context = if String.length(context) > 0 do
      context
    else
      ActivityPub.generate_context_id
    end

    to = [
      "https://www.w3.org/ns/activitystreams#Public"
    ]

    mentions = :xmerl_xpath.string('/entry/link[@rel="mentioned" and @ostatus:object-type="http://activitystrea.ms/schema/1.0/person"]', doc)
    |> Enum.map(fn(person) -> string_from_xpath("@href", person) end)

    to = to ++ mentions

    date = string_from_xpath("/entry/published", doc)

    object = %{
      "type" => "Note",
      "to" => to,
      "content" => content_html,
      "published" => date,
      "context" => context,
      "actor" => actor.ap_id
    }

    inReplyTo = string_from_xpath("/entry/thr:in-reply-to[1]/@href", doc)

    object = if inReplyTo do
      Map.put(object, "inReplyTo", inReplyTo)
    else
      object
    end

    ActivityPub.create(to, actor, context, object, %{}, date)
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
        nickname: info.nickname,
        ap_id: info.uri,
        info: info
      }
      Repo.insert(Ecto.Changeset.change(%User{}, data))
    end
  end

  # TODO: Just takes the first one for now.
  defp make_avatar_object(author_doc) do
    href = string_from_xpath("/author[1]/link[@rel=\"avatar\"]/@href", author_doc)
    type = string_from_xpath("/author[1]/link[@rel=\"avatar\"]/@type", author_doc)

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
