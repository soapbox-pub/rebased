defmodule Pleroma.Web.TwitterAPI.TwitterAPI do
  alias Pleroma.{User, Activity, Repo, Object}
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.TwitterAPI.Representers.ActivityRepresenter

  import Ecto.Query

  def create_status(user = %User{}, data = %{}) do
    attachments = Enum.map(data["media_ids"] || [], fn (media_id) ->
      Repo.get(Object, media_id).data
    end)

    context = ActivityPub.generate_context_id

    content = HtmlSanitizeEx.strip_tags(data["status"])

    mentions = parse_mentions(content)

    default_to = [
      User.ap_followers(user),
      "https://www.w3.org/ns/activitystreams#Public"
    ]

    to = default_to ++ Enum.map(mentions, fn ({_, %{ap_id: ap_id}}) -> ap_id end)

    content_html = add_user_links(content, mentions)

    date = make_date()

    activity = %{
      "type" => "Create",
      "to" => to,
      "actor" => user.ap_id,
      "object" => %{
        "type" => "Note",
        "to" => to,
        "content" => content_html,
        "published" => date,
        "context" => context,
        "attachment" => attachments,
        "actor" => user.ap_id
      },
      "published" => date,
      "context" => context
    }

    # Wire up reply info.
    activity = with inReplyToId when not is_nil(inReplyToId) <- data["in_reply_to_status_id"],
                    inReplyTo <- Repo.get(Activity, inReplyToId),
                    context <- inReplyTo.data["context"]
               do

               to = activity["to"] ++ [inReplyTo.data["actor"]]

               activity
               |> put_in(["to"], to)
               |> put_in(["context"], context)
               |> put_in(["object", "context"], context)
               |> put_in(["object", "inReplyTo"], inReplyTo.data["object"]["id"])
               |> put_in(["object", "inReplyToStatusId"], inReplyToId)
               |> put_in(["statusnetConversationId"], inReplyTo.data["statusnetConversationId"])
               |> put_in(["object", "statusnetConversationId"], inReplyTo.data["statusnetConversationId"])
               else _e ->
                 activity
               end

    with {:ok, activity} <- ActivityPub.insert(activity) do
      add_conversation_id(activity)
    end
  end

  def fetch_friend_statuses(user, opts \\ %{}) do
    ActivityPub.fetch_activities([user.ap_id | user.following], opts)
    |> activities_to_statuses(%{for: user})
  end

  def fetch_public_statuses(user, opts \\ %{}) do
    ActivityPub.fetch_public_activities(opts)
    |> activities_to_statuses(%{for: user})
  end

  def fetch_conversation(user, id) do
    query = from activity in Activity,
      where: fragment("? @> ?", activity.data, ^%{ statusnetConversationId: id}),
      limit: 1

    with %Activity{} = activity <- Repo.one(query),
         context <- activity.data["context"],
         activities <- ActivityPub.fetch_activities_for_context(context),
         statuses <- activities |> activities_to_statuses(%{for: user})
    do
      statuses
    else e ->
      IO.inspect(e)
      []
    end
  end

  def fetch_status(user, id) do
    with %Activity{} = activity <- Repo.get(Activity, id) do
      activity_to_status(activity, %{for: user})
    end
  end

  def follow(%User{} = follower, followed_id) do
    with %User{} = followed <- Repo.get(User, followed_id),
         { :ok, follower } <- User.follow(follower, followed),
         { :ok, activity } <- ActivityPub.insert(%{
           "type" => "Follow",
           "actor" => follower.ap_id,
           "object" => followed.ap_id,
           "published" => make_date()
         })
    do
      { :ok, follower, followed, activity }
    end
  end

  def unfollow(%User{} = follower, followed_id) do
    with %User{} = followed <- Repo.get(User, followed_id),
         { :ok, follower } <- User.unfollow(follower, followed)
    do
      { :ok, follower, followed }
    end
  end

  def upload(%Plug.Upload{} = file) do
    {:ok, object} = ActivityPub.upload(file)

    url = List.first(object.data["url"])
    href = url["href"]
    type = url["mediaType"]

    # Fake this as good as possible...
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rsp stat="ok" xmlns:atom="http://www.w3.org/2005/Atom">
      <mediaid>#{object.id}</mediaid>
      <media_id>#{object.id}</media_id>
      <media_id_string>#{object.id}</media_id_string>
      <media_url>#{href}</media_url>
      <mediaurl>#{href}</mediaurl>
      <atom:link rel="enclosure" href="#{href}" type="#{type}"></atom:link>
    </rsp>
    """
  end

  def parse_mentions(text) do
    # Modified from https://www.w3.org/TR/html5/forms.html#valid-e-mail-address
    regex = ~r/@[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@?[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*/

    Regex.scan(regex, text)
    |> List.flatten
    |> Enum.uniq
    |> Enum.map(fn ("@" <> match = full_match) -> {full_match, Repo.get_by(User, nickname: match)} end)
    |> Enum.filter(fn ({_match, user}) -> user end)
  end

  def add_user_links(text, mentions) do
    Enum.reduce(mentions, text, fn ({match, %User{ap_id: ap_id}}, text) -> String.replace(text, match, "<a href='#{ap_id}'>#{match}</a>") end)
  end

  defp add_conversation_id(activity) do
    if is_integer(activity.data["statusnetConversationId"]) do
      {:ok, activity}
    else
      data = activity.data
      |> put_in(["object", "statusnetConversationId"], activity.id)
      |> put_in(["statusnetConversationId"], activity.id)

      changeset = Ecto.Changeset.change(activity, data: data)
      Repo.update(changeset)
    end
  end

  defp activities_to_statuses(activities, opts) do
    Enum.map(activities, fn(activity) ->
      activity_to_status(activity, opts)
    end)
  end

  defp activity_to_status(activity, opts) do
    actor = get_in(activity.data, ["actor"])
    user = Repo.get_by!(User, ap_id: actor)
    mentioned_users = Repo.all(from user in User, where: user.ap_id in ^activity.data["to"])
    ActivityRepresenter.to_map(activity, Map.merge(opts, %{user: user, mentioned: mentioned_users}))
  end

  defp make_date do
    DateTime.utc_now() |> DateTime.to_iso8601
  end
end
