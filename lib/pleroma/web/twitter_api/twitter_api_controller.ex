defmodule Pleroma.Web.TwitterAPI.Controller do
  use Pleroma.Web, :controller
  alias Pleroma.Formatter
  alias Pleroma.Web.TwitterAPI.{TwitterAPI, UserView, ActivityView, NotificationView}
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils, as: CommonUtils
  alias Pleroma.{Repo, Activity, Object, User, Notification}
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Utils
  alias Ecto.Changeset

  require Logger

  plug(:only_if_public_instance when action in [:public_timeline, :public_and_external_timeline])
  action_fallback(:errors)

  def verify_credentials(%{assigns: %{user: user}} = conn, _params) do
    token = Phoenix.Token.sign(conn, "user socket", user.id)
    render(conn, UserView, "show.json", %{user: user, token: token})
  end

  def status_update(%{assigns: %{user: user}} = conn, %{"status" => _} = status_data) do
    with media_ids <- extract_media_ids(status_data),
         {:ok, activity} <-
           TwitterAPI.create_status(user, Map.put(status_data, "media_ids", media_ids)) do
      conn
      |> json(ActivityView.render("activity.json", activity: activity, for: user))
    else
      _ -> empty_status_reply(conn)
    end
  end

  def status_update(conn, _status_data) do
    empty_status_reply(conn)
  end

  defp empty_status_reply(conn) do
    bad_request_reply(conn, "Client must provide a 'status' parameter with a value.")
  end

  defp extract_media_ids(status_data) do
    with media_ids when not is_nil(media_ids) <- status_data["media_ids"],
         split_ids <- String.split(media_ids, ","),
         clean_ids <- Enum.reject(split_ids, fn id -> String.length(id) == 0 end) do
      clean_ids
    else
      _e -> []
    end
  end

  def public_and_external_timeline(%{assigns: %{user: user}} = conn, params) do
    params =
      params
      |> Map.put("type", ["Create", "Announce"])
      |> Map.put("blocking_user", user)

    activities = ActivityPub.fetch_public_activities(params)

    conn
    |> render(ActivityView, "index.json", %{activities: activities, for: user})
  end

  def public_timeline(%{assigns: %{user: user}} = conn, params) do
    params =
      params
      |> Map.put("type", ["Create", "Announce"])
      |> Map.put("local_only", true)
      |> Map.put("blocking_user", user)

    activities = ActivityPub.fetch_public_activities(params)

    conn
    |> render(ActivityView, "index.json", %{activities: activities, for: user})
  end

  def friends_timeline(%{assigns: %{user: user}} = conn, params) do
    params =
      params
      |> Map.put("type", ["Create", "Announce", "Follow", "Like"])
      |> Map.put("blocking_user", user)
      |> Map.put("user", user)

    activities =
      ActivityPub.fetch_activities([user.ap_id | user.following], params)
      |> ActivityPub.contain_timeline(user)

    conn
    |> render(ActivityView, "index.json", %{activities: activities, for: user})
  end

  def show_user(conn, params) do
    with {:ok, shown} <- TwitterAPI.get_user(params) do
      if user = conn.assigns.user do
        render(conn, UserView, "show.json", %{user: shown, for: user})
      else
        render(conn, UserView, "show.json", %{user: shown})
      end
    else
      {:error, msg} ->
        bad_request_reply(conn, msg)
    end
  end

  def user_timeline(%{assigns: %{user: user}} = conn, params) do
    case TwitterAPI.get_user(user, params) do
      {:ok, target_user} ->
        activities = ActivityPub.fetch_user_activities(target_user, user, params)

        conn
        |> render(ActivityView, "index.json", %{activities: activities, for: user})

      {:error, msg} ->
        bad_request_reply(conn, msg)
    end
  end

  def mentions_timeline(%{assigns: %{user: user}} = conn, params) do
    params =
      params
      |> Map.put("type", ["Create", "Announce", "Follow", "Like"])
      |> Map.put("blocking_user", user)

    activities = ActivityPub.fetch_activities([user.ap_id], params)

    conn
    |> render(ActivityView, "index.json", %{activities: activities, for: user})
  end

  def dm_timeline(%{assigns: %{user: user}} = conn, params) do
    query =
      ActivityPub.fetch_activities_query(
        [user.ap_id],
        Map.merge(params, %{"type" => "Create", "user" => user, visibility: "direct"})
      )

    activities = Repo.all(query)

    conn
    |> render(ActivityView, "index.json", %{activities: activities, for: user})
  end

  def notifications(%{assigns: %{user: user}} = conn, params) do
    notifications = Notification.for_user(user, params)

    conn
    |> render(NotificationView, "notification.json", %{notifications: notifications, for: user})
  end

  def notifications_read(%{assigns: %{user: user}} = conn, %{"latest_id" => latest_id} = params) do
    Notification.set_read_up_to(user, latest_id)

    notifications = Notification.for_user(user, params)

    conn
    |> render(NotificationView, "notification.json", %{notifications: notifications, for: user})
  end

  def notifications_read(%{assigns: %{user: user}} = conn, _) do
    bad_request_reply(conn, "You need to specify latest_id")
  end

  def follow(%{assigns: %{user: user}} = conn, params) do
    case TwitterAPI.follow(user, params) do
      {:ok, user, followed, _activity} ->
        render(conn, UserView, "show.json", %{user: followed, for: user})

      {:error, msg} ->
        forbidden_json_reply(conn, msg)
    end
  end

  def block(%{assigns: %{user: user}} = conn, params) do
    case TwitterAPI.block(user, params) do
      {:ok, user, blocked} ->
        render(conn, UserView, "show.json", %{user: blocked, for: user})

      {:error, msg} ->
        forbidden_json_reply(conn, msg)
    end
  end

  def unblock(%{assigns: %{user: user}} = conn, params) do
    case TwitterAPI.unblock(user, params) do
      {:ok, user, blocked} ->
        render(conn, UserView, "show.json", %{user: blocked, for: user})

      {:error, msg} ->
        forbidden_json_reply(conn, msg)
    end
  end

  def delete_post(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with {:ok, activity} <- TwitterAPI.delete(user, id) do
      render(conn, ActivityView, "activity.json", %{activity: activity, for: user})
    end
  end

  def unfollow(%{assigns: %{user: user}} = conn, params) do
    case TwitterAPI.unfollow(user, params) do
      {:ok, user, unfollowed} ->
        render(conn, UserView, "show.json", %{user: unfollowed, for: user})

      {:error, msg} ->
        forbidden_json_reply(conn, msg)
    end
  end

  def fetch_status(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %Activity{} = activity <- Repo.get(Activity, id),
         true <- ActivityPub.visible_for_user?(activity, user) do
      render(conn, ActivityView, "activity.json", %{activity: activity, for: user})
    end
  end

  def fetch_conversation(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    id = String.to_integer(id)

    with context when is_binary(context) <- TwitterAPI.conversation_id_to_context(id),
         activities <-
           ActivityPub.fetch_activities_for_context(context, %{
             "blocking_user" => user,
             "user" => user
           }) do
      conn
      |> render(ActivityView, "index.json", %{activities: activities, for: user})
    end
  end

  @doc """
  Updates metadata of uploaded media object.
  Derived from [Twitter API endpoint](https://developer.twitter.com/en/docs/media/upload-media/api-reference/post-media-metadata-create).
  """
  def update_media(%{assigns: %{user: _}} = conn, %{"media_id" => id} = data) do
    description = get_in(data, ["alt_text", "text"]) || data["name"] || data["description"]

    with %Object{} = object <- Repo.get(Object, id),
         is_binary(description) do
      new_data = Map.put(object.data, "name", description)

      {:ok, _} =
        object
        |> Object.change(%{data: new_data})
        |> Repo.update()
    end

    conn
    |> put_status(:no_content)
    |> json("")
  end

  def upload(conn, %{"media" => media}) do
    response = TwitterAPI.upload(media)

    conn
    |> put_resp_content_type("application/atom+xml")
    |> send_resp(200, response)
  end

  def upload_json(conn, %{"media" => media}) do
    response = TwitterAPI.upload(media, "json")

    conn
    |> json_reply(200, response)
  end

  def get_by_id_or_ap_id(id) do
    activity = Repo.get(Activity, id) || Activity.get_create_activity_by_object_ap_id(id)

    if activity.data["type"] == "Create" do
      activity
    else
      Activity.get_create_activity_by_object_ap_id(activity.data["object"])
    end
  end

  def favorite(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with {_, {:ok, id}} <- {:param_cast, Ecto.Type.cast(:integer, id)},
         {:ok, activity} <- TwitterAPI.fav(user, id) do
      render(conn, ActivityView, "activity.json", %{activity: activity, for: user})
    end
  end

  def unfavorite(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with {_, {:ok, id}} <- {:param_cast, Ecto.Type.cast(:integer, id)},
         {:ok, activity} <- TwitterAPI.unfav(user, id) do
      render(conn, ActivityView, "activity.json", %{activity: activity, for: user})
    end
  end

  def retweet(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with {_, {:ok, id}} <- {:param_cast, Ecto.Type.cast(:integer, id)},
         {:ok, activity} <- TwitterAPI.repeat(user, id) do
      render(conn, ActivityView, "activity.json", %{activity: activity, for: user})
    end
  end

  def unretweet(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with {_, {:ok, id}} <- {:param_cast, Ecto.Type.cast(:integer, id)},
         {:ok, activity} <- TwitterAPI.unrepeat(user, id) do
      render(conn, ActivityView, "activity.json", %{activity: activity, for: user})
    end
  end

  def register(conn, params) do
    with {:ok, user} <- TwitterAPI.register_user(params) do
      render(conn, UserView, "show.json", %{user: user})
    else
      {:error, errors} ->
        conn
        |> json_reply(400, Jason.encode!(errors))
    end
  end

  def update_avatar(%{assigns: %{user: user}} = conn, params) do
    {:ok, object} = ActivityPub.upload(params, type: :avatar)
    change = Changeset.change(user, %{avatar: object.data})
    {:ok, user} = User.update_and_set_cache(change)
    CommonAPI.update(user)

    render(conn, UserView, "show.json", %{user: user, for: user})
  end

  def update_banner(%{assigns: %{user: user}} = conn, params) do
    with {:ok, object} <- ActivityPub.upload(%{"img" => params["banner"]}, type: :banner),
         new_info <- %{"banner" => object.data},
         info_cng <- User.Info.profile_update(user.info, new_info),
         changeset <- Ecto.Changeset.change(user) |> Ecto.Changeset.put_embed(:info, info_cng),
         {:ok, user} <- User.update_and_set_cache(changeset) do
      CommonAPI.update(user)
      %{"url" => [%{"href" => href} | _]} = object.data
      response = %{url: href} |> Jason.encode!()

      conn
      |> json_reply(200, response)
    end
  end

  def update_background(%{assigns: %{user: user}} = conn, params) do
    with {:ok, object} <- ActivityPub.upload(params, type: :background),
         new_info <- %{"background" => object.data},
         info_cng <- User.Info.profile_update(user.info, new_info),
         changeset <- Ecto.Changeset.change(user) |> Ecto.Changeset.put_embed(:info, info_cng),
         {:ok, _user} <- User.update_and_set_cache(changeset) do
      %{"url" => [%{"href" => href} | _]} = object.data
      response = %{url: href} |> Jason.encode!()

      conn
      |> json_reply(200, response)
    end
  end

  def external_profile(%{assigns: %{user: current_user}} = conn, %{"profileurl" => uri}) do
    with {:ok, user_map} <- TwitterAPI.get_external_profile(current_user, uri),
         response <- Jason.encode!(user_map) do
      conn
      |> json_reply(200, response)
    else
      _e ->
        conn
        |> put_status(404)
        |> json(%{error: "Can't find user"})
    end
  end

  def followers(conn, params) do
    with {:ok, user} <- TwitterAPI.get_user(conn.assigns[:user], params),
         {:ok, followers} <- User.get_followers(user) do
      render(conn, UserView, "index.json", %{users: followers, for: conn.assigns[:user]})
    else
      _e -> bad_request_reply(conn, "Can't get followers")
    end
  end

  def friends(conn, params) do
    with {:ok, user} <- TwitterAPI.get_user(conn.assigns[:user], params),
         {:ok, friends} <- User.get_friends(user) do
      render(conn, UserView, "index.json", %{users: friends, for: conn.assigns[:user]})
    else
      _e -> bad_request_reply(conn, "Can't get friends")
    end
  end

  def friend_requests(conn, params) do
    with {:ok, user} <- TwitterAPI.get_user(conn.assigns[:user], params),
         {:ok, friend_requests} <- User.get_follow_requests(user) do
      render(conn, UserView, "index.json", %{users: friend_requests, for: conn.assigns[:user]})
    else
      _e -> bad_request_reply(conn, "Can't get friend requests")
    end
  end

  def approve_friend_request(conn, %{"user_id" => uid} = params) do
    with followed <- conn.assigns[:user],
         uid when is_number(uid) <- String.to_integer(uid),
         %User{} = follower <- Repo.get(User, uid),
         {:ok, follower} <- User.maybe_follow(follower, followed),
         %Activity{} = follow_activity <- Utils.fetch_latest_follow(follower, followed),
         {:ok, follow_activity} <- Utils.update_follow_state(follow_activity, "accept"),
         {:ok, _activity} <-
           ActivityPub.accept(%{
             to: [follower.ap_id],
             actor: followed.ap_id,
             object: follow_activity.data["id"],
             type: "Accept"
           }) do
      render(conn, UserView, "show.json", %{user: follower, for: followed})
    else
      e -> bad_request_reply(conn, "Can't approve user: #{inspect(e)}")
    end
  end

  def deny_friend_request(conn, %{"user_id" => uid} = params) do
    with followed <- conn.assigns[:user],
         uid when is_number(uid) <- String.to_integer(uid),
         %User{} = follower <- Repo.get(User, uid),
         %Activity{} = follow_activity <- Utils.fetch_latest_follow(follower, followed),
         {:ok, follow_activity} <- Utils.update_follow_state(follow_activity, "reject"),
         {:ok, _activity} <-
           ActivityPub.reject(%{
             to: [follower.ap_id],
             actor: followed.ap_id,
             object: follow_activity.data["id"],
             type: "Reject"
           }) do
      render(conn, UserView, "show.json", %{user: follower, for: followed})
    else
      e -> bad_request_reply(conn, "Can't deny user: #{inspect(e)}")
    end
  end

  def friends_ids(%{assigns: %{user: user}} = conn, _params) do
    with {:ok, friends} <- User.get_friends(user) do
      ids =
        friends
        |> Enum.map(fn x -> x.id end)
        |> Jason.encode!()

      json(conn, ids)
    else
      _e -> bad_request_reply(conn, "Can't get friends")
    end
  end

  def empty_array(conn, _params) do
    json(conn, Jason.encode!([]))
  end

  def raw_empty_array(conn, _params) do
    json(conn, [])
  end

  defp build_info_cng(user, params) do
    info_params =
      ["no_rich_text", "locked"]
      |> Enum.reduce(%{}, fn key, res ->
        if value = params[key] do
          Map.put(res, key, value == "true")
        else
          res
        end
      end)

    info_params =
      if value = params["default_scope"] do
        Map.put(info_params, "default_scope", value)
      else
        info_params
      end

    User.Info.profile_update(user.info, info_params)
  end

  defp parse_profile_bio(user, params) do
    if bio = params["description"] do
      Map.put(params, "bio", User.parse_bio(bio, user))
    else
      params
    end
  end

  def update_profile(%{assigns: %{user: user}} = conn, params) do
    params = parse_profile_bio(user, params)
    info_cng = build_info_cng(user, params)

    with changeset <- User.update_changeset(user, params),
         changeset <- Ecto.Changeset.put_embed(changeset, :info, info_cng),
         {:ok, user} <- User.update_and_set_cache(changeset) do
      CommonAPI.update(user)
      render(conn, UserView, "user.json", %{user: user, for: user})
    else
      error ->
        Logger.debug("Can't update user: #{inspect(error)}")
        bad_request_reply(conn, "Can't update user")
    end
  end

  def search(%{assigns: %{user: user}} = conn, %{"q" => _query} = params) do
    activities = TwitterAPI.search(user, params)

    conn
    |> render(ActivityView, "index.json", %{activities: activities, for: user})
  end

  def search_user(%{assigns: %{user: user}} = conn, %{"query" => query}) do
    users = User.search(query, true)

    conn
    |> render(UserView, "index.json", %{users: users, for: user})
  end

  defp bad_request_reply(conn, error_message) do
    json = error_json(conn, error_message)
    json_reply(conn, 400, json)
  end

  defp json_reply(conn, status, json) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, json)
  end

  defp forbidden_json_reply(conn, error_message) do
    json = error_json(conn, error_message)
    json_reply(conn, 403, json)
  end

  def only_if_public_instance(conn = %{conn: %{assigns: %{user: _user}}}, _), do: conn

  def only_if_public_instance(conn, _) do
    if Keyword.get(Application.get_env(:pleroma, :instance), :public) do
      conn
    else
      conn
      |> forbidden_json_reply("Invalid credentials.")
      |> halt()
    end
  end

  defp error_json(conn, error_message) do
    %{"error" => error_message, "request" => conn.request_path} |> Jason.encode!()
  end

  def errors(conn, {:param_cast, _}) do
    conn
    |> put_status(400)
    |> json("Invalid parameters")
  end

  def errors(conn, _) do
    conn
    |> put_status(500)
    |> json("Something went wrong")
  end
end
