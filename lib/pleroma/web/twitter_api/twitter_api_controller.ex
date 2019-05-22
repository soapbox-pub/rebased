# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.Controller do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [json_response: 3]

  alias Ecto.Changeset
  alias Pleroma.Activity
  alias Pleroma.Formatter
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.TwitterAPI.ActivityView
  alias Pleroma.Web.TwitterAPI.NotificationView
  alias Pleroma.Web.TwitterAPI.TokenView
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Pleroma.Web.TwitterAPI.UserView

  require Logger

  plug(:only_if_public_instance when action in [:public_timeline, :public_and_external_timeline])
  action_fallback(:errors)

  def verify_credentials(%{assigns: %{user: user}} = conn, _params) do
    token = Phoenix.Token.sign(conn, "user socket", user.id)

    conn
    |> put_view(UserView)
    |> render("show.json", %{user: user, token: token, for: user})
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
    |> put_view(ActivityView)
    |> render("index.json", %{activities: activities, for: user})
  end

  def public_timeline(%{assigns: %{user: user}} = conn, params) do
    params =
      params
      |> Map.put("type", ["Create", "Announce"])
      |> Map.put("local_only", true)
      |> Map.put("blocking_user", user)

    activities = ActivityPub.fetch_public_activities(params)

    conn
    |> put_view(ActivityView)
    |> render("index.json", %{activities: activities, for: user})
  end

  def friends_timeline(%{assigns: %{user: user}} = conn, params) do
    params =
      params
      |> Map.put("type", ["Create", "Announce", "Follow", "Like"])
      |> Map.put("blocking_user", user)
      |> Map.put("user", user)

    activities = ActivityPub.fetch_activities([user.ap_id | user.following], params)

    conn
    |> put_view(ActivityView)
    |> render("index.json", %{activities: activities, for: user})
  end

  def show_user(conn, params) do
    for_user = conn.assigns.user

    with {:ok, shown} <- TwitterAPI.get_user(params),
         true <-
           User.auth_active?(shown) ||
             (for_user && (for_user.id == shown.id || User.superuser?(for_user))) do
      params =
        if for_user do
          %{user: shown, for: for_user}
        else
          %{user: shown}
        end

      conn
      |> put_view(UserView)
      |> render("show.json", params)
    else
      {:error, msg} ->
        bad_request_reply(conn, msg)

      false ->
        conn
        |> put_status(404)
        |> json(%{error: "Unconfirmed user"})
    end
  end

  def user_timeline(%{assigns: %{user: user}} = conn, params) do
    case TwitterAPI.get_user(user, params) do
      {:ok, target_user} ->
        # Twitter and ActivityPub use a different name and sense for this parameter.
        {include_rts, params} = Map.pop(params, "include_rts")

        params =
          case include_rts do
            x when x == "false" or x == "0" -> Map.put(params, "exclude_reblogs", "true")
            _ -> params
          end

        activities = ActivityPub.fetch_user_activities(target_user, user, params)

        conn
        |> put_view(ActivityView)
        |> render("index.json", %{activities: activities, for: user})

      {:error, msg} ->
        bad_request_reply(conn, msg)
    end
  end

  def mentions_timeline(%{assigns: %{user: user}} = conn, params) do
    params =
      params
      |> Map.put("type", ["Create", "Announce", "Follow", "Like"])
      |> Map.put("blocking_user", user)
      |> Map.put(:visibility, ~w[unlisted public private])

    activities = ActivityPub.fetch_activities([user.ap_id], params)

    conn
    |> put_view(ActivityView)
    |> render("index.json", %{activities: activities, for: user})
  end

  def dm_timeline(%{assigns: %{user: user}} = conn, params) do
    params =
      params
      |> Map.put("type", "Create")
      |> Map.put("blocking_user", user)
      |> Map.put("user", user)
      |> Map.put(:visibility, "direct")
      |> Map.put(:order, :desc)

    activities =
      ActivityPub.fetch_activities_query([user.ap_id], params)
      |> Repo.all()

    conn
    |> put_view(ActivityView)
    |> render("index.json", %{activities: activities, for: user})
  end

  def notifications(%{assigns: %{user: user}} = conn, params) do
    notifications = Notification.for_user(user, params)

    conn
    |> put_view(NotificationView)
    |> render("notification.json", %{notifications: notifications, for: user})
  end

  def notifications_read(%{assigns: %{user: user}} = conn, %{"latest_id" => latest_id} = params) do
    Notification.set_read_up_to(user, latest_id)

    notifications = Notification.for_user(user, params)

    conn
    |> put_view(NotificationView)
    |> render("notification.json", %{notifications: notifications, for: user})
  end

  def notifications_read(%{assigns: %{user: _user}} = conn, _) do
    bad_request_reply(conn, "You need to specify latest_id")
  end

  def follow(%{assigns: %{user: user}} = conn, params) do
    case TwitterAPI.follow(user, params) do
      {:ok, user, followed, _activity} ->
        conn
        |> put_view(UserView)
        |> render("show.json", %{user: followed, for: user})

      {:error, msg} ->
        forbidden_json_reply(conn, msg)
    end
  end

  def block(%{assigns: %{user: user}} = conn, params) do
    case TwitterAPI.block(user, params) do
      {:ok, user, blocked} ->
        conn
        |> put_view(UserView)
        |> render("show.json", %{user: blocked, for: user})

      {:error, msg} ->
        forbidden_json_reply(conn, msg)
    end
  end

  def unblock(%{assigns: %{user: user}} = conn, params) do
    case TwitterAPI.unblock(user, params) do
      {:ok, user, blocked} ->
        conn
        |> put_view(UserView)
        |> render("show.json", %{user: blocked, for: user})

      {:error, msg} ->
        forbidden_json_reply(conn, msg)
    end
  end

  def delete_post(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with {:ok, activity} <- TwitterAPI.delete(user, id) do
      conn
      |> put_view(ActivityView)
      |> render("activity.json", %{activity: activity, for: user})
    end
  end

  def unfollow(%{assigns: %{user: user}} = conn, params) do
    case TwitterAPI.unfollow(user, params) do
      {:ok, user, unfollowed} ->
        conn
        |> put_view(UserView)
        |> render("show.json", %{user: unfollowed, for: user})

      {:error, msg} ->
        forbidden_json_reply(conn, msg)
    end
  end

  def fetch_status(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %Activity{} = activity <- Activity.get_by_id(id),
         true <- Visibility.visible_for_user?(activity, user) do
      conn
      |> put_view(ActivityView)
      |> render("activity.json", %{activity: activity, for: user})
    end
  end

  def fetch_conversation(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with context when is_binary(context) <- Utils.conversation_id_to_context(id),
         activities <-
           ActivityPub.fetch_activities_for_context(context, %{
             "blocking_user" => user,
             "user" => user
           }) do
      conn
      |> put_view(ActivityView)
      |> render("index.json", %{activities: activities, for: user})
    end
  end

  @doc """
  Updates metadata of uploaded media object.
  Derived from [Twitter API endpoint](https://developer.twitter.com/en/docs/media/upload-media/api-reference/post-media-metadata-create).
  """
  def update_media(%{assigns: %{user: user}} = conn, %{"media_id" => id} = data) do
    object = Repo.get(Object, id)
    description = get_in(data, ["alt_text", "text"]) || data["name"] || data["description"]

    {conn, status, response_body} =
      cond do
        !object ->
          {halt(conn), :not_found, ""}

        !Object.authorize_mutation(object, user) ->
          {halt(conn), :forbidden, "You can only update your own uploads."}

        !is_binary(description) ->
          {conn, :not_modified, ""}

        true ->
          new_data = Map.put(object.data, "name", description)

          {:ok, _} =
            object
            |> Object.change(%{data: new_data})
            |> Repo.update()

          {conn, :no_content, ""}
      end

    conn
    |> put_status(status)
    |> json(response_body)
  end

  def upload(%{assigns: %{user: user}} = conn, %{"media" => media}) do
    response = TwitterAPI.upload(media, user)

    conn
    |> put_resp_content_type("application/atom+xml")
    |> send_resp(200, response)
  end

  def upload_json(%{assigns: %{user: user}} = conn, %{"media" => media}) do
    response = TwitterAPI.upload(media, user, "json")

    conn
    |> json_reply(200, response)
  end

  def get_by_id_or_ap_id(id) do
    activity = Activity.get_by_id(id) || Activity.get_create_by_object_ap_id(id)

    if activity.data["type"] == "Create" do
      activity
    else
      Activity.get_create_by_object_ap_id(activity.data["object"])
    end
  end

  def favorite(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with {:ok, activity} <- TwitterAPI.fav(user, id) do
      conn
      |> put_view(ActivityView)
      |> render("activity.json", %{activity: activity, for: user})
    else
      _ -> json_reply(conn, 400, Jason.encode!(%{}))
    end
  end

  def unfavorite(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with {:ok, activity} <- TwitterAPI.unfav(user, id) do
      conn
      |> put_view(ActivityView)
      |> render("activity.json", %{activity: activity, for: user})
    else
      _ -> json_reply(conn, 400, Jason.encode!(%{}))
    end
  end

  def retweet(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with {:ok, activity} <- TwitterAPI.repeat(user, id) do
      conn
      |> put_view(ActivityView)
      |> render("activity.json", %{activity: activity, for: user})
    else
      _ -> json_reply(conn, 400, Jason.encode!(%{}))
    end
  end

  def unretweet(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with {:ok, activity} <- TwitterAPI.unrepeat(user, id) do
      conn
      |> put_view(ActivityView)
      |> render("activity.json", %{activity: activity, for: user})
    else
      _ -> json_reply(conn, 400, Jason.encode!(%{}))
    end
  end

  def pin(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with {:ok, activity} <- TwitterAPI.pin(user, id) do
      conn
      |> put_view(ActivityView)
      |> render("activity.json", %{activity: activity, for: user})
    else
      {:error, message} -> bad_request_reply(conn, message)
      err -> err
    end
  end

  def unpin(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with {:ok, activity} <- TwitterAPI.unpin(user, id) do
      conn
      |> put_view(ActivityView)
      |> render("activity.json", %{activity: activity, for: user})
    else
      {:error, message} -> bad_request_reply(conn, message)
      err -> err
    end
  end

  def register(conn, params) do
    with {:ok, user} <- TwitterAPI.register_user(params) do
      conn
      |> put_view(UserView)
      |> render("show.json", %{user: user})
    else
      {:error, errors} ->
        conn
        |> json_reply(400, Jason.encode!(errors))
    end
  end

  def password_reset(conn, params) do
    nickname_or_email = params["email"] || params["nickname"]

    with {:ok, _} <- TwitterAPI.password_reset(nickname_or_email) do
      json_response(conn, :no_content, "")
    end
  end

  def confirm_email(conn, %{"user_id" => uid, "token" => token}) do
    with %User{} = user <- User.get_cached_by_id(uid),
         true <- user.local,
         true <- user.info.confirmation_pending,
         true <- user.info.confirmation_token == token,
         info_change <- User.Info.confirmation_changeset(user.info, need_confirmation: false),
         changeset <- Changeset.change(user) |> Changeset.put_embed(:info, info_change),
         {:ok, _} <- User.update_and_set_cache(changeset) do
      conn
      |> redirect(to: "/")
    end
  end

  def resend_confirmation_email(conn, params) do
    nickname_or_email = params["email"] || params["nickname"]

    with %User{} = user <- User.get_by_nickname_or_email(nickname_or_email),
         {:ok, _} <- User.try_send_confirmation_email(user) do
      conn
      |> json_response(:no_content, "")
    end
  end

  def update_avatar(%{assigns: %{user: user}} = conn, %{"img" => ""}) do
    change = Changeset.change(user, %{avatar: nil})
    {:ok, user} = User.update_and_set_cache(change)
    CommonAPI.update(user)

    conn
    |> put_view(UserView)
    |> render("show.json", %{user: user, for: user})
  end

  def update_avatar(%{assigns: %{user: user}} = conn, params) do
    {:ok, object} = ActivityPub.upload(params, type: :avatar)
    change = Changeset.change(user, %{avatar: object.data})
    {:ok, user} = User.update_and_set_cache(change)
    CommonAPI.update(user)

    conn
    |> put_view(UserView)
    |> render("show.json", %{user: user, for: user})
  end

  def update_banner(%{assigns: %{user: user}} = conn, %{"banner" => ""}) do
    with new_info <- %{"banner" => %{}},
         info_cng <- User.Info.profile_update(user.info, new_info),
         changeset <- Ecto.Changeset.change(user) |> Ecto.Changeset.put_embed(:info, info_cng),
         {:ok, user} <- User.update_and_set_cache(changeset) do
      CommonAPI.update(user)
      response = %{url: nil} |> Jason.encode!()

      conn
      |> json_reply(200, response)
    end
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

  def update_background(%{assigns: %{user: user}} = conn, %{"img" => ""}) do
    with new_info <- %{"background" => %{}},
         info_cng <- User.Info.profile_update(user.info, new_info),
         changeset <- Ecto.Changeset.change(user) |> Ecto.Changeset.put_embed(:info, info_cng),
         {:ok, _user} <- User.update_and_set_cache(changeset) do
      response = %{url: nil} |> Jason.encode!()

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

  def followers(%{assigns: %{user: for_user}} = conn, params) do
    {:ok, page} = Ecto.Type.cast(:integer, params["page"] || 1)

    with {:ok, user} <- TwitterAPI.get_user(for_user, params),
         {:ok, followers} <- User.get_followers(user, page) do
      followers =
        cond do
          for_user && user.id == for_user.id -> followers
          user.info.hide_followers -> []
          true -> followers
        end

      conn
      |> put_view(UserView)
      |> render("index.json", %{users: followers, for: conn.assigns[:user]})
    else
      _e -> bad_request_reply(conn, "Can't get followers")
    end
  end

  def friends(%{assigns: %{user: for_user}} = conn, params) do
    {:ok, page} = Ecto.Type.cast(:integer, params["page"] || 1)
    {:ok, export} = Ecto.Type.cast(:boolean, params["all"] || false)

    page = if export, do: nil, else: page

    with {:ok, user} <- TwitterAPI.get_user(conn.assigns[:user], params),
         {:ok, friends} <- User.get_friends(user, page) do
      friends =
        cond do
          for_user && user.id == for_user.id -> friends
          user.info.hide_follows -> []
          true -> friends
        end

      conn
      |> put_view(UserView)
      |> render("index.json", %{users: friends, for: conn.assigns[:user]})
    else
      _e -> bad_request_reply(conn, "Can't get friends")
    end
  end

  def oauth_tokens(%{assigns: %{user: user}} = conn, _params) do
    with oauth_tokens <- Token.get_user_tokens(user) do
      conn
      |> put_view(TokenView)
      |> render("index.json", %{tokens: oauth_tokens})
    end
  end

  def revoke_token(%{assigns: %{user: user}} = conn, %{"id" => id} = _params) do
    Token.delete_user_token(user, id)

    json_reply(conn, 201, "")
  end

  def blocks(%{assigns: %{user: user}} = conn, _params) do
    with blocked_users <- User.blocked_users(user) do
      conn
      |> put_view(UserView)
      |> render("index.json", %{users: blocked_users, for: user})
    end
  end

  def friend_requests(conn, params) do
    with {:ok, user} <- TwitterAPI.get_user(conn.assigns[:user], params),
         {:ok, friend_requests} <- User.get_follow_requests(user) do
      conn
      |> put_view(UserView)
      |> render("index.json", %{users: friend_requests, for: conn.assigns[:user]})
    else
      _e -> bad_request_reply(conn, "Can't get friend requests")
    end
  end

  def approve_friend_request(conn, %{"user_id" => uid} = _params) do
    with followed <- conn.assigns[:user],
         %User{} = follower <- User.get_cached_by_id(uid),
         {:ok, follower} <- CommonAPI.accept_follow_request(follower, followed) do
      conn
      |> put_view(UserView)
      |> render("show.json", %{user: follower, for: followed})
    else
      e -> bad_request_reply(conn, "Can't approve user: #{inspect(e)}")
    end
  end

  def deny_friend_request(conn, %{"user_id" => uid} = _params) do
    with followed <- conn.assigns[:user],
         %User{} = follower <- User.get_cached_by_id(uid),
         {:ok, follower} <- CommonAPI.reject_follow_request(follower, followed) do
      conn
      |> put_view(UserView)
      |> render("show.json", %{user: follower, for: followed})
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
      ["no_rich_text", "locked", "hide_followers", "hide_follows", "hide_favorites", "show_role"]
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
      emojis_text = (params["description"] || "") <> " " <> (params["name"] || "")

      emojis =
        ((user.info.emoji || []) ++ Formatter.get_emoji_map(emojis_text))
        |> Enum.dedup()

      user_info =
        user.info
        |> Map.put(
          "emoji",
          emojis
        )

      params
      |> Map.put("bio", User.parse_bio(bio, user))
      |> Map.put("info", user_info)
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

      conn
      |> put_view(UserView)
      |> render("user.json", %{user: user, for: user})
    else
      error ->
        Logger.debug("Can't update user: #{inspect(error)}")
        bad_request_reply(conn, "Can't update user")
    end
  end

  def search(%{assigns: %{user: user}} = conn, %{"q" => _query} = params) do
    activities = TwitterAPI.search(user, params)

    conn
    |> put_view(ActivityView)
    |> render("index.json", %{activities: activities, for: user})
  end

  def search_user(%{assigns: %{user: user}} = conn, %{"query" => query}) do
    users = User.search(query, resolve: true, for_user: user)

    conn
    |> put_view(UserView)
    |> render("index.json", %{users: users, for: user})
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

  def only_if_public_instance(%{assigns: %{user: %User{}}} = conn, _), do: conn

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
