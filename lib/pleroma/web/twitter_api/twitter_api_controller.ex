defmodule Pleroma.Web.TwitterAPI.Controller do
  use Pleroma.Web, :controller
  alias Pleroma.Formatter
  alias Pleroma.Web.TwitterAPI.{TwitterAPI, UserView, ActivityView, NotificationView}
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils, as: CommonUtils
  alias Pleroma.{Repo, Activity, User, Notification}
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Utils
  alias Ecto.Changeset

  require Logger

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

  def notifications(%{assigns: %{user: user}} = conn, params) do
    notifications = Notification.for_user(user, params)

    conn
    |> render(NotificationView, "notification.json", %{notifications: notifications, for: user})
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
    upload_limit =
      Application.get_env(:pleroma, :instance)
      |> Keyword.fetch(:avatar_upload_limit)

    {:ok, object} = ActivityPub.upload(params, upload_limit)
    change = Changeset.change(user, %{avatar: object.data})
    {:ok, user} = User.update_and_set_cache(change)
    CommonAPI.update(user)

    render(conn, UserView, "show.json", %{user: user, for: user})
  end

  def update_banner(%{assigns: %{user: user}} = conn, params) do
    upload_limit =
      Application.get_env(:pleroma, :instance)
      |> Keyword.fetch(:banner_upload_limit)

    with {:ok, object} <- ActivityPub.upload(%{"img" => params["banner"]}, upload_limit),
         new_info <- Map.put(user.info, "banner", object.data),
         change <- User.info_changeset(user, %{info: new_info}),
         {:ok, user} <- User.update_and_set_cache(change) do
      CommonAPI.update(user)
      %{"url" => [%{"href" => href} | _]} = object.data
      response = %{url: href} |> Jason.encode!()

      conn
      |> json_reply(200, response)
    end
  end

  def update_background(%{assigns: %{user: user}} = conn, params) do
    upload_limit =
      Application.get_env(:pleroma, :instance)
      |> Keyword.fetch(:background_upload_limit)

    with {:ok, object} <- ActivityPub.upload(params, upload_limit),
         new_info <- Map.put(user.info, "background", object.data),
         change <- User.info_changeset(user, %{info: new_info}),
         {:ok, _user} <- User.update_and_set_cache(change) do
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

  def update_most_recent_notification(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with id when is_number(id) <- String.to_integer(id),
         info <- user.info,
         mrn <- max(id, user.info["most_recent_notification"] || 0),
         updated_info <- Map.put(info, "most_recent_notification", mrn),
         changeset <- User.info_changeset(user, %{info: updated_info}),
         {:ok, _user} <- User.update_and_set_cache(changeset) do
      conn
      |> json_reply(200, Jason.encode!(mrn))
    else
      _e -> bad_request_reply(conn, "Can't update.")
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

  def update_profile(%{assigns: %{user: user}} = conn, params) do
    params =
      if bio = params["description"] do
        mentions = Formatter.parse_mentions(bio)
        tags = Formatter.parse_tags(bio)

        emoji =
          (user.info["source_data"]["tag"] || [])
          |> Enum.filter(fn %{"type" => t} -> t == "Emoji" end)
          |> Enum.map(fn %{"icon" => %{"url" => url}, "name" => name} ->
            {String.trim(name, ":"), url}
          end)

        bio_html = CommonUtils.format_input(bio, mentions, tags, "text/plain")
        Map.put(params, "bio", bio_html |> Formatter.emojify(emoji))
      else
        params
      end

    user =
      if locked = params["locked"] do
        with locked <- locked == "true",
             new_info <- Map.put(user.info, "locked", locked),
             change <- User.info_changeset(user, %{info: new_info}),
             {:ok, user} <- User.update_and_set_cache(change) do
          user
        else
          _e -> user
        end
      else
        user
      end

    user =
      if no_rich_text = params["no_rich_text"] do
        with no_rich_text <- no_rich_text == "true",
             new_info <- Map.put(user.info, "no_rich_text", no_rich_text),
             change <- User.info_changeset(user, %{info: new_info}),
             {:ok, user} <- User.update_and_set_cache(change) do
          user
        else
          _e -> user
        end
      else
        user
      end

    user =
      if default_scope = params["default_scope"] do
        with new_info <- Map.put(user.info, "default_scope", default_scope),
             change <- User.info_changeset(user, %{info: new_info}),
             {:ok, user} <- User.update_and_set_cache(change) do
          user
        else
          _e -> user
        end
      else
        user
      end

    with changeset <- User.update_changeset(user, params),
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
