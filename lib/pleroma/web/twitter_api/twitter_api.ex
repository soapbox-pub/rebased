defmodule Pleroma.Web.TwitterAPI.TwitterAPI do
  alias Pleroma.{User, Activity, Repo, Object}
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.TwitterAPI.Representers.ActivityRepresenter
  alias Pleroma.Web.TwitterAPI.UserView
  alias Pleroma.Web.{OStatus, CommonAPI}
  import Ecto.Query

  @httpoison Application.get_env(:pleroma, :httpoison)

  def create_status(%User{} = user, %{"status" => _} = data) do
    CommonAPI.post(user, data)
  end

  def fetch_friend_statuses(user, opts \\ %{}) do
    opts = opts
    |> Map.put("blocking_user", user)
    |> Map.put("user", user)

    ActivityPub.fetch_activities([user.ap_id | user.following], opts)
    |> activities_to_statuses(%{for: user})
  end

  def fetch_public_statuses(user, opts \\ %{}) do
    opts = Map.put(opts, "local_only", true)
    opts = Map.put(opts, "blocking_user", user)
    ActivityPub.fetch_public_activities(opts)
    |> activities_to_statuses(%{for: user})
  end

  def fetch_public_and_external_statuses(user, opts \\ %{}) do
    opts = Map.put(opts, "blocking_user", user)
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
    with context when is_binary(context) <- conversation_id_to_context(id),
         activities <- ActivityPub.fetch_activities_for_context(context, %{"blocking_user" => user}),
         statuses <- activities |> activities_to_statuses(%{for: user})
    do
      statuses
    else _e ->
      []
    end
  end

  def fetch_status(user, id) do
    with %Activity{} = activity <- Repo.get(Activity, id) do
      activity_to_status(activity, %{for: user})
    end
  end

  def follow(%User{} = follower, params) do
    with {:ok, %User{} = followed} <- get_user(params),
         {:ok, follower} <- User.follow(follower, followed),
         {:ok, activity} <- ActivityPub.follow(follower, followed)
    do
      {:ok, follower, followed, activity}
    else
      err -> err
    end
  end

  def unfollow(%User{} = follower, params) do
    with { :ok, %User{} = unfollowed } <- get_user(params),
         { :ok, follower, follow_activity } <- User.unfollow(follower, unfollowed),
         { :ok, _activity } <- ActivityPub.insert(%{
           "type" => "Undo",
           "actor" => follower.ap_id,
           "object" => follow_activity.data["id"], # get latest Follow for these users
           "published" => make_date()
         })
    do
      { :ok, follower, unfollowed }
    else
      err -> err
    end
  end

  def block(%User{} = blocker, params) do
    with {:ok, %User{} = blocked} <- get_user(params),
         {:ok, blocker} <- User.block(blocker, blocked)
    do
      {:ok, blocker, blocked}
    else
      err -> err
    end
  end

  def unblock(%User{} = blocker, params) do
    with {:ok, %User{} = blocked} <- get_user(params),
         {:ok, blocker} <- User.unblock(blocker, blocked)
    do
      {:ok, blocker, blocked}
    else
      err -> err
    end
  end

  def repeat(%User{} = user, ap_id_or_id) do
    with {:ok, _announce, %{data: %{"id" => id}}} = CommonAPI.repeat(ap_id_or_id, user),
         %Activity{} = activity <- Activity.get_create_activity_by_object_ap_id(id),
         status <- activity_to_status(activity, %{for: user}) do
      {:ok, status}
    end
  end

  def fav(%User{} = user, ap_id_or_id) do
    with {:ok, _announce, %{data: %{"id" => id}}} = CommonAPI.favorite(ap_id_or_id, user),
         %Activity{} = activity <- Activity.get_create_activity_by_object_ap_id(id),
         status <- activity_to_status(activity, %{for: user}) do
      {:ok, status}
    end
  end

  def unfav(%User{} = user, ap_id_or_id) do
    with {:ok, %{data: %{"id" => id}}} = CommonAPI.unfavorite(ap_id_or_id, user),
         %Activity{} = activity <- Activity.get_create_activity_by_object_ap_id(id),
         status <- activity_to_status(activity, %{for: user}) do
      {:ok, status}
    end
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
      {:ok, user}
    else
      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
      |> Poison.encode!
      {:error, %{error: errors}}
    end
  end

  def get_by_id_or_nickname(id_or_nickname) do
    if !is_integer(id_or_nickname) && :error == Integer.parse(id_or_nickname) do
      Repo.get_by(User, nickname: id_or_nickname)
    else
      Repo.get(User, id_or_nickname)
    end
  end

  def get_user(user \\ nil, params) do
    case params do
      %{"user_id" => user_id} ->
        case target = get_by_id_or_nickname(user_id) do
          nil ->
            {:error, "No user with such user_id"}
          _ ->
            {:ok, target}
        end
      %{"screen_name" => nickname} ->
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

  defp parse_int(string, default)
  defp parse_int(string, default) when is_binary(string) do
    with {n, _} <- Integer.parse(string) do
      n
    else
      _e -> default
    end
  end
  defp parse_int(_, default), do: default

  def search(user, %{"q" => query} = params) do
    limit = parse_int(params["rpp"], 20)
    page = parse_int(params["page"], 1)
    offset = (page - 1) * limit

    q = from a in Activity,
      where: fragment("?->>'type' = 'Create'", a.data),
      where: fragment("to_tsvector('english', ?->'object'->>'content') @@ plainto_tsquery('english', ?)", a.data, ^query),
      limit: ^limit,
      offset: ^offset,
      order_by: [desc: :inserted_at] # this one isn't indexed so psql won't take the wrong index.

    activities = Repo.all(q)
    activities_to_statuses(activities, %{for: user})
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

  defp activity_to_status(%Activity{data: %{"type" => "Delete"}} = activity, opts) do
    actor = get_in(activity.data, ["actor"])
    user = User.get_cached_by_ap_id(actor)
    ActivityRepresenter.to_map(activity, Map.merge(opts, %{user: user}))
  end

  defp activity_to_status(activity, opts) do
    actor = get_in(activity.data, ["actor"])
    user = User.get_cached_by_ap_id(actor)
    # mentioned_users = Repo.all(from user in User, where: user.ap_id in ^activity.data["to"])
    mentioned_users = Enum.map(activity.data["to"] || [], fn (ap_id) ->
      if ap_id do
        User.get_cached_by_ap_id(ap_id)
      else
        nil
      end
    end)
    |> Enum.filter(&(&1))

    ActivityRepresenter.to_map(activity, Map.merge(opts, %{user: user, mentioned: mentioned_users}))
  end

  defp make_date do
    DateTime.utc_now() |> DateTime.to_iso8601
  end

  def context_to_conversation_id(context) do
    with %Object{id: id} <- Object.get_cached_by_ap_id(context) do
      id
      else _e ->
        changeset = Object.context_mapping(context)
        case Repo.insert(changeset) do
          {:ok, %{id: id}} -> id
          # This should be solved by an upsert, but it seems ecto
          # has problems accessing the constraint inside the jsonb.
          {:error, _} -> Object.get_cached_by_ap_id(context).id
        end
    end
  end

  def conversation_id_to_context(id) do
    with %Object{data: %{"id" => context}} <- Repo.get(Object, id) do
      context
    else _e ->
      {:error, "No such conversation"}
    end
  end

  def get_external_profile(for_user, uri) do
    with {:ok, %User{} = user} <- OStatus.find_or_make_user(uri) do
      spawn(fn ->
        with url <- user.info["topic"],
             {:ok, %{body: body}} <- @httpoison.get(url, [], follow_redirect: true, timeout: 10000, recv_timeout: 20000) do
          OStatus.handle_incoming(body)
        end
      end)
      {:ok, UserView.render("show.json", %{user: user, for: for_user})}
    else _e ->
        {:error, "Couldn't find user"}
    end
  end
end
