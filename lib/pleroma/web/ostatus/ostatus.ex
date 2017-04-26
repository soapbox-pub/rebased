defmodule Pleroma.Web.OStatus do
  import Ecto.Query
  require Logger

  alias Pleroma.{Repo, User, Web}
  alias Pleroma.Web.ActivityPub.ActivityPub

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
    {doc, _rest} = :xmerl_scan.string(to_charlist(xml_string))

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

    [author] = :xmerl_xpath.string('/entry/author[1]', doc)
    {:ok, actor} = find_or_make_user(author)

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

  def find_or_make_user(author_doc) do
    {:xmlObj, :string, uri } = :xmerl_xpath.string('string(/author[1]/uri)', author_doc)

    query = from user in User,
      where: user.local == false and fragment("? @> ?", user.info, ^%{ostatus_uri: to_string(uri)})

    user = Repo.one(query)

    if is_nil(user) do
      make_user(author_doc)
    else
      {:ok, user}
    end
  end

  defp string_from_xpath(xpath, doc) do
    {:xmlObj, :string, res} = :xmerl_xpath.string('string(#{xpath})', doc)

    res = res
    |> to_string
    |> String.trim

    if res == "", do: nil, else: res
  end

  def make_user(author_doc) do
    author = string_from_xpath("/author[1]/uri", author_doc)
    name = string_from_xpath("/author[1]/name", author_doc)
    preferredUsername = string_from_xpath("/author[1]/poco:preferredUsername", author_doc)
    displayName = string_from_xpath("/author[1]/poco:displayName", author_doc)
    avatar = make_avatar_object(author_doc)

    data = %{
      local: false,
      name: preferredUsername || name,
      nickname: displayName || name,
      ap_id: author,
      info: %{
        "ostatus_uri" => author,
        "host" => URI.parse(author).host,
        "system" => "ostatus"
      },
      avatar: avatar
    }

    Repo.insert(Ecto.Changeset.change(%User{}, data))
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
end
