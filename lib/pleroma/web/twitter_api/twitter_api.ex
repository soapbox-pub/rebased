defmodule Pleroma.Web.TwitterAPI.TwitterAPI do
  alias Pleroma.{User, Activity, Repo, Object}
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.TwitterAPI.Representers.{ActivityRepresenter, UserRepresenter}

  import Ecto.Query

  def to_for_user_and_mentions(user, mentions) do
    default_to = [
      User.ap_followers(user),
      "https://www.w3.org/ns/activitystreams#Public"
    ]

    to = default_to ++ Enum.map(mentions, fn ({_, %{ap_id: ap_id}}) -> ap_id end)
  end

  def format_input(text, mentions) do
    content = HtmlSanitizeEx.strip_tags(text)
    |> String.replace("\n", "<br>")
    |> add_user_links(mentions)
  end

  def attachments_from_ids(ids) do
    Enum.map(ids || [], fn (media_id) ->
      Repo.get(Object, media_id).data
    end)
  end

  def get_replied_to_activity(id) when not is_nil(id) do
    Repo.get(Activity, id)
  end

  def get_replied_to_activity(_), do: nil

  def create_status(user = %User{}, data = %{"status" => status}) do
    attachments = attachments_from_ids(data["media_ids"])
    context = ActivityPub.generate_context_id
    mentions = parse_mentions(status)
    content_html = format_input(status, mentions)
    to = to_for_user_and_mentions(user, mentions)
    date = make_date()

    inReplyTo = get_replied_to_activity(data["in_reply_to_status_id"])

    # Wire up reply info.
    [to, context, object, additional] =
      if inReplyTo do
      context = inReplyTo.data["context"]
      to = to ++ [inReplyTo.data["actor"]]

      object = %{
        "type" => "Note",
        "to" => to,
        "content" => content_html,
        "published" => date,
        "context" => context,
        "attachment" => attachments,
        "actor" => user.ap_id,
        "inReplyTo" => inReplyTo.data["object"]["id"],
        "inReplyToStatusId" => inReplyTo.id,
        "statusnetConversationId" => inReplyTo.data["statusnetConversationId"]
      }
      additional = %{
        "statusnetConversationId" => inReplyTo.data["statusnetConversationId"]
      }

      [to, context, object, additional]
      else
      object = %{
        "type" => "Note",
        "to" => to,
        "content" => content_html,
        "published" => date,
        "context" => context,
        "attachment" => attachments,
        "actor" => user.ap_id
      }
      [to, context, object, %{}]
    end

    ActivityPub.create(to, user, context, object, additional, data)
  end

  def fetch_friend_statuses(user, opts \\ %{}) do
    ActivityPub.fetch_activities([user.ap_id | user.following], opts)
    |> activities_to_statuses(%{for: user})
  end

  def fetch_public_statuses(user, opts \\ %{}) do
    ActivityPub.fetch_public_activities(opts)
    |> activities_to_statuses(%{for: user})
  end

  def fetch_user_statuses(user, opts \\ %{}) do
    ActivityPub.fetch_activities([], opts)
    |> activities_to_statuses(%{for: user})
  end

  def fetch_mentions(user, opts \\ %{}) do
    ActivityPub.fetch_activities([user.ap_id], opts)
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
    else
      err -> err
    end
  end

  def unfollow(%User{} = follower, followed_id) do
    with %User{} = followed <- Repo.get(User, followed_id),
         { :ok, follower } <- User.unfollow(follower, followed)
    do
      { :ok, follower, followed }
    else
      err -> err
    end
  end

  def favorite(%User{} = user, %Activity{data: %{"object" => object}} = activity) do
    object = Object.get_by_ap_id(object["id"])

    {:ok, _like_activity, object} = ActivityPub.like(user, object)
    new_data = activity.data
    |> Map.put("object", object.data)

    status = %{activity | data: new_data}
    |> activity_to_status(%{for: user})

    {:ok, status}
  end

  def unfavorite(%User{} = user, %Activity{data: %{"object" => object}} = activity) do
    object = Object.get_by_ap_id(object["id"])

    {:ok, object} = ActivityPub.unlike(user, object)
    new_data = activity.data
    |> Map.put("object", object.data)

    status = %{activity | data: new_data}
    |> activity_to_status(%{for: user})

    {:ok, status}
  end

  def retweet(%User{} = user, %Activity{data: %{"object" => object}} = activity) do
    object = Object.get_by_ap_id(object["id"])

    {:ok, _announce_activity, object} = ActivityPub.announce(user, object)
    new_data = activity.data
    |> Map.put("object", object.data)

    status = %{activity | data: new_data}
    |> activity_to_status(%{for: user})

    {:ok, status}
  end

  def upload(%Plug.Upload{} = file, format \\ "xml") do
    {:ok, object} = ActivityPub.upload(file)

    url = List.first(object.data["url"])
    href = url["href"]
    type = url["mediaType"]

    case format do
      "xml" ->
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
      "json" ->
        %{
          media_id: object.id,
          media_id_string: "#{object.id}}",
          media_url: href,
          size: 0
        } |> Poison.encode!
    end
  end

  def parse_mentions(text) do
    # Modified from https://www.w3.org/TR/html5/forms.html#valid-e-mail-address
    regex = ~r/@[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@?[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*/

    Regex.scan(regex, text)
    |> List.flatten
    |> Enum.uniq
    |> Enum.map(fn ("@" <> match = full_match) -> {full_match, User.get_cached_by_nickname(match)} end)
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

      object = Object.get_by_ap_id(activity.data["object"]["id"])

      changeset = Ecto.Changeset.change(object, data: data["object"])
      Repo.update(changeset)

      changeset = Ecto.Changeset.change(activity, data: data)
      Repo.update(changeset)
    end
  end

  def register_user(params) do
    params = %{
      nickname: params["nickname"],
      name: params["fullname"],
      bio: params["bio"],
      email: params["email"],
      password: params["password"],
      password_confirmation: params["confirm"]
    }

    changeset = User.register_changeset(%User{}, params)

    with {:ok, user} <- Repo.insert(changeset) do
      {:ok, UserRepresenter.to_map(user)}
    else
      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
      |> Poison.encode!
        {:error, %{error: errors}}
    end
  end

  def get_user(user, params) do
    case params do
      %{ "user_id" => user_id } ->
        case target = Repo.get(User, user_id) do
          nil ->
            {:error, "No user with such user_id"}
          _ ->
            {:ok, target}
        end
      %{ "screen_name" => nickname } ->
        case target = Repo.get_by(User, nickname: nickname) do
          nil ->
            {:error, "No user with such screen_name"}
          _ ->
            {:ok, target}
        end
      _ ->
        if user do
          {:ok, user}
        else
          {:error, "You need to specify screen_name or user_id"}
        end
    end
  end

  defp activities_to_statuses(activities, opts) do
    Enum.map(activities, fn(activity) ->
      activity_to_status(activity, opts)
    end)
  end

  # For likes, fetch the liked activity, too.
  defp activity_to_status(%Activity{data: %{"type" => "Like"}} = activity, opts) do
    actor = get_in(activity.data, ["actor"])
    user = User.get_cached_by_ap_id(actor)
    [liked_activity] = Activity.all_by_object_ap_id(activity.data["object"])

    ActivityRepresenter.to_map(activity, Map.merge(opts, %{user: user, liked_activity: liked_activity}))
  end

  # For announces, fetch the announced activity and the user.
  defp activity_to_status(%Activity{data: %{"type" => "Announce"}} = activity, opts) do
    actor = get_in(activity.data, ["actor"])
    user = User.get_cached_by_ap_id(actor)
    [announced_activity] = Activity.all_by_object_ap_id(activity.data["object"])
    announced_actor = User.get_cached_by_ap_id(announced_activity.data["actor"])

    ActivityRepresenter.to_map(activity, Map.merge(opts, %{users: [user, announced_actor], announced_activity: announced_activity}))
  end

  defp activity_to_status(activity, opts) do
    actor = get_in(activity.data, ["actor"])
    user = User.get_cached_by_ap_id(actor)
    # mentioned_users = Repo.all(from user in User, where: user.ap_id in ^activity.data["to"])
    mentioned_users = Enum.map(activity.data["to"] || [], fn (ap_id) ->
      User.get_cached_by_ap_id(ap_id)
    end)
    |> Enum.filter(&(&1))

    ActivityRepresenter.to_map(activity, Map.merge(opts, %{user: user, mentioned: mentioned_users}))
  end

  defp make_date do
    DateTime.utc_now() |> DateTime.to_iso8601
  end
end
