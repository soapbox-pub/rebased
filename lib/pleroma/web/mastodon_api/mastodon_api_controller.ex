defmodule Pleroma.Web.MastodonAPI.MastodonAPIController do
  use Pleroma.Web, :controller
  alias Pleroma.{Repo, Object, Activity, User, Notification, Stats}
  alias Pleroma.Web
  alias Pleroma.Web.MastodonAPI.{StatusView, AccountView, MastodonView, ListView, FilterView}
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.OAuth.{Authorization, Token, App}
  alias Pleroma.Web.MediaProxy
  alias Comeonin.Pbkdf2
  import Ecto.Query
  require Logger

  @httpoison Application.get_env(:pleroma, :httpoison)

  action_fallback(:errors)

  def create_app(conn, params) do
    with cs <- App.register_changeset(%App{}, params) |> IO.inspect(),
         {:ok, app} <- Repo.insert(cs) |> IO.inspect() do
      res = %{
        id: app.id |> to_string,
        name: app.client_name,
        client_id: app.client_id,
        client_secret: app.client_secret,
        redirect_uri: app.redirect_uris,
        website: app.website
      }

      json(conn, res)
    end
  end

  defp add_if_present(
         map,
         params,
         params_field,
         map_field,
         value_function \\ fn x -> {:ok, x} end
       ) do
    if Map.has_key?(params, params_field) do
      case value_function.(params[params_field]) do
        {:ok, new_value} -> Map.put(map, map_field, new_value)
        :error -> map
      end
    else
      map
    end
  end

  def update_credentials(%{assigns: %{user: user}} = conn, params) do
    original_user = user

    user_params =
      %{}
      |> add_if_present(params, "display_name", :name)
      |> add_if_present(params, "note", :bio, fn value -> {:ok, User.parse_bio(value)} end)
      |> add_if_present(params, "avatar", :avatar, fn value ->
        with %Plug.Upload{} <- value,
             {:ok, object} <- ActivityPub.upload(value, type: :avatar) do
          {:ok, object.data}
        else
          _ -> :error
        end
      end)

    info_params =
      %{}
      |> add_if_present(params, "locked", :locked, fn value -> {:ok, value == "true"} end)
      |> add_if_present(params, "header", :banner, fn value ->
        with %Plug.Upload{} <- value,
             {:ok, object} <- ActivityPub.upload(value, type: :banner) do
          {:ok, object.data}
        else
          _ -> :error
        end
      end)

    info_cng = User.Info.mastodon_profile_update(user.info, info_params)

    with changeset <- User.update_changeset(user, user_params),
         changeset <- Ecto.Changeset.put_embed(changeset, :info, info_cng),
         {:ok, user} <- User.update_and_set_cache(changeset) do
      if original_user != user do
        CommonAPI.update(user)
      end

      json(conn, AccountView.render("account.json", %{user: user, for: user}))
    else
      _e ->
        conn
        |> put_status(403)
        |> json(%{error: "Invalid request"})
    end
  end

  def verify_credentials(%{assigns: %{user: user}} = conn, _) do
    account = AccountView.render("account.json", %{user: user, for: user})
    json(conn, account)
  end

  def user(%{assigns: %{user: for_user}} = conn, %{"id" => id}) do
    with %User{} = user <- Repo.get(User, id) do
      account = AccountView.render("account.json", %{user: user, for: for_user})
      json(conn, account)
    else
      _e ->
        conn
        |> put_status(404)
        |> json(%{error: "Can't find user"})
    end
  end

  @mastodon_api_level "2.5.0"

  def masto_instance(conn, _params) do
    instance = Pleroma.Config.get(:instance)

    response = %{
      uri: Web.base_url(),
      title: Keyword.get(instance, :name),
      description: Keyword.get(instance, :description),
      version: "#{@mastodon_api_level} (compatible; #{Pleroma.Application.named_version()})",
      email: Keyword.get(instance, :email),
      urls: %{
        streaming_api: String.replace(Pleroma.Web.Endpoint.static_url(), "http", "ws")
      },
      stats: Stats.get_stats(),
      thumbnail: Web.base_url() <> "/instance/thumbnail.jpeg",
      max_toot_chars: Keyword.get(instance, :limit)
    }

    json(conn, response)
  end

  def peers(conn, _params) do
    json(conn, Stats.get_peers())
  end

  defp mastodonized_emoji do
    Pleroma.Emoji.get_all()
    |> Enum.map(fn {shortcode, relative_url} ->
      url = to_string(URI.merge(Web.base_url(), relative_url))

      %{
        "shortcode" => shortcode,
        "static_url" => url,
        "visible_in_picker" => true,
        "url" => url
      }
    end)
  end

  def custom_emojis(conn, _params) do
    mastodon_emoji = mastodonized_emoji()
    json(conn, mastodon_emoji)
  end

  defp add_link_headers(conn, method, activities, param \\ nil, params \\ %{}) do
    last = List.last(activities)
    first = List.first(activities)

    if last do
      min = last.id
      max = first.id

      {next_url, prev_url} =
        if param do
          {
            mastodon_api_url(
              Pleroma.Web.Endpoint,
              method,
              param,
              Map.merge(params, %{max_id: min})
            ),
            mastodon_api_url(
              Pleroma.Web.Endpoint,
              method,
              param,
              Map.merge(params, %{since_id: max})
            )
          }
        else
          {
            mastodon_api_url(
              Pleroma.Web.Endpoint,
              method,
              Map.merge(params, %{max_id: min})
            ),
            mastodon_api_url(
              Pleroma.Web.Endpoint,
              method,
              Map.merge(params, %{since_id: max})
            )
          }
        end

      conn
      |> put_resp_header("link", "<#{next_url}>; rel=\"next\", <#{prev_url}>; rel=\"prev\"")
    else
      conn
    end
  end

  def home_timeline(%{assigns: %{user: user}} = conn, params) do
    params =
      params
      |> Map.put("type", ["Create", "Announce"])
      |> Map.put("blocking_user", user)
      |> Map.put("user", user)

    activities =
      ActivityPub.fetch_activities([user.ap_id | user.following], params)
      |> ActivityPub.contain_timeline(user)
      |> Enum.reverse()

    conn
    |> add_link_headers(:home_timeline, activities)
    |> render(StatusView, "index.json", %{activities: activities, for: user, as: :activity})
  end

  def public_timeline(%{assigns: %{user: user}} = conn, params) do
    local_only = params["local"] in [true, "True", "true", "1"]

    params =
      params
      |> Map.put("type", ["Create", "Announce"])
      |> Map.put("local_only", local_only)
      |> Map.put("blocking_user", user)

    activities =
      ActivityPub.fetch_public_activities(params)
      |> Enum.reverse()

    conn
    |> add_link_headers(:public_timeline, activities, false, %{"local" => local_only})
    |> render(StatusView, "index.json", %{activities: activities, for: user, as: :activity})
  end

  def user_statuses(%{assigns: %{user: reading_user}} = conn, params) do
    with %User{} = user <- Repo.get(User, params["id"]) do
      # Since Pleroma has no "pinned" posts feature, we'll just set an empty list here
      activities =
        if params["pinned"] == "true" do
          []
        else
          ActivityPub.fetch_user_activities(user, reading_user, params)
        end

      conn
      |> add_link_headers(:user_statuses, activities, params["id"])
      |> render(StatusView, "index.json", %{
        activities: activities,
        for: reading_user,
        as: :activity
      })
    end
  end

  def dm_timeline(%{assigns: %{user: user}} = conn, params) do
    query =
      ActivityPub.fetch_activities_query(
        [user.ap_id],
        Map.merge(params, %{"type" => "Create", visibility: "direct"})
      )

    activities = Repo.all(query)

    conn
    |> add_link_headers(:dm_timeline, activities)
    |> render(StatusView, "index.json", %{activities: activities, for: user, as: :activity})
  end

  def get_status(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %Activity{} = activity <- Repo.get(Activity, id),
         true <- ActivityPub.visible_for_user?(activity, user) do
      try_render(conn, StatusView, "status.json", %{activity: activity, for: user})
    end
  end

  def get_context(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %Activity{} = activity <- Repo.get(Activity, id),
         activities <-
           ActivityPub.fetch_activities_for_context(activity.data["context"], %{
             "blocking_user" => user,
             "user" => user
           }),
         activities <-
           activities |> Enum.filter(fn %{id: aid} -> to_string(aid) != to_string(id) end),
         activities <-
           activities |> Enum.filter(fn %{data: %{"type" => type}} -> type == "Create" end),
         grouped_activities <- Enum.group_by(activities, fn %{id: id} -> id < activity.id end) do
      result = %{
        ancestors:
          StatusView.render(
            "index.json",
            for: user,
            activities: grouped_activities[true] || [],
            as: :activity
          )
          |> Enum.reverse(),
        descendants:
          StatusView.render(
            "index.json",
            for: user,
            activities: grouped_activities[false] || [],
            as: :activity
          )
          |> Enum.reverse()
      }

      json(conn, result)
    end
  end

  def post_status(conn, %{"status" => "", "media_ids" => media_ids} = params)
      when length(media_ids) > 0 do
    params =
      params
      |> Map.put("status", ".")

    post_status(conn, params)
  end

  def post_status(%{assigns: %{user: user}} = conn, %{"status" => _} = params) do
    params =
      params
      |> Map.put("in_reply_to_status_id", params["in_reply_to_id"])
      |> Map.put("no_attachment_links", true)

    idempotency_key =
      case get_req_header(conn, "idempotency-key") do
        [key] -> key
        _ -> Ecto.UUID.generate()
      end

    {:ok, activity} =
      Cachex.fetch!(:idempotency_cache, idempotency_key, fn _ -> CommonAPI.post(user, params) end)

    try_render(conn, StatusView, "status.json", %{activity: activity, for: user, as: :activity})
  end

  def delete_status(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with {:ok, %Activity{}} <- CommonAPI.delete(id, user) do
      json(conn, %{})
    else
      _e ->
        conn
        |> put_status(403)
        |> json(%{error: "Can't delete this post"})
    end
  end

  def reblog_status(%{assigns: %{user: user}} = conn, %{"id" => ap_id_or_id}) do
    with {:ok, announce, _activity} <- CommonAPI.repeat(ap_id_or_id, user) do
      try_render(conn, StatusView, "status.json", %{activity: announce, for: user, as: :activity})
    end
  end

  def unreblog_status(%{assigns: %{user: user}} = conn, %{"id" => ap_id_or_id}) do
    with {:ok, _unannounce, %{data: %{"id" => id}}} <- CommonAPI.unrepeat(ap_id_or_id, user),
         %Activity{} = activity <- Activity.get_create_activity_by_object_ap_id(id) do
      try_render(conn, StatusView, "status.json", %{activity: activity, for: user, as: :activity})
    end
  end

  def fav_status(%{assigns: %{user: user}} = conn, %{"id" => ap_id_or_id}) do
    with {:ok, _fav, %{data: %{"id" => id}}} <- CommonAPI.favorite(ap_id_or_id, user),
         %Activity{} = activity <- Activity.get_create_activity_by_object_ap_id(id) do
      try_render(conn, StatusView, "status.json", %{activity: activity, for: user, as: :activity})
    end
  end

  def unfav_status(%{assigns: %{user: user}} = conn, %{"id" => ap_id_or_id}) do
    with {:ok, _, _, %{data: %{"id" => id}}} <- CommonAPI.unfavorite(ap_id_or_id, user),
         %Activity{} = activity <- Activity.get_create_activity_by_object_ap_id(id) do
      try_render(conn, StatusView, "status.json", %{activity: activity, for: user, as: :activity})
    end
  end

  def notifications(%{assigns: %{user: user}} = conn, params) do
    notifications = Notification.for_user(user, params)

    result =
      Enum.map(notifications, fn x ->
        render_notification(user, x)
      end)
      |> Enum.filter(& &1)

    conn
    |> add_link_headers(:notifications, notifications)
    |> json(result)
  end

  def get_notification(%{assigns: %{user: user}} = conn, %{"id" => id} = _params) do
    with {:ok, notification} <- Notification.get(user, id) do
      json(conn, render_notification(user, notification))
    else
      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Jason.encode!(%{"error" => reason}))
    end
  end

  def clear_notifications(%{assigns: %{user: user}} = conn, _params) do
    Notification.clear(user)
    json(conn, %{})
  end

  def dismiss_notification(%{assigns: %{user: user}} = conn, %{"id" => id} = _params) do
    with {:ok, _notif} <- Notification.dismiss(user, id) do
      json(conn, %{})
    else
      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Jason.encode!(%{"error" => reason}))
    end
  end

  def relationships(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    id = List.wrap(id)
    q = from(u in User, where: u.id in ^id)
    targets = Repo.all(q)
    render(conn, AccountView, "relationships.json", %{user: user, targets: targets})
  end

  # Instead of returning a 400 when no "id" params is present, Mastodon returns an empty array.
  def relationships(%{assigns: %{user: user}} = conn, _) do
    conn
    |> json([])
  end

  def update_media(%{assigns: %{user: user}} = conn, data) do
    with %Object{} = object <- Repo.get(Object, data["id"]),
         true <- Object.authorize_mutation(object, user),
         true <- is_binary(data["description"]),
         description <- data["description"] do
      new_data = %{object.data | "name" => description}

      {:ok, _} =
        object
        |> Object.change(%{data: new_data})
        |> Repo.update()

      attachment_data = Map.put(new_data, "id", object.id)
      render(conn, StatusView, "attachment.json", %{attachment: attachment_data})
    end
  end

  def upload(%{assigns: %{user: user}} = conn, %{"file" => file} = data) do
    with {:ok, object} <-
           ActivityPub.upload(file,
             actor: User.ap_id(user),
             description: Map.get(data, "description")
           ) do
      attachment_data = Map.put(object.data, "id", object.id)
      render(conn, StatusView, "attachment.json", %{attachment: attachment_data})
    end
  end

  def favourited_by(conn, %{"id" => id}) do
    with %Activity{data: %{"object" => %{"likes" => likes}}} <- Repo.get(Activity, id) do
      q = from(u in User, where: u.ap_id in ^likes)
      users = Repo.all(q)
      render(conn, AccountView, "accounts.json", %{users: users, as: :user})
    else
      _ -> json(conn, [])
    end
  end

  def reblogged_by(conn, %{"id" => id}) do
    with %Activity{data: %{"object" => %{"announcements" => announces}}} <- Repo.get(Activity, id) do
      q = from(u in User, where: u.ap_id in ^announces)
      users = Repo.all(q)
      render(conn, AccountView, "accounts.json", %{users: users, as: :user})
    else
      _ -> json(conn, [])
    end
  end

  def hashtag_timeline(%{assigns: %{user: user}} = conn, params) do
    local_only = params["local"] in [true, "True", "true", "1"]

    params =
      params
      |> Map.put("type", "Create")
      |> Map.put("local_only", local_only)
      |> Map.put("blocking_user", user)
      |> Map.put("tag", String.downcase(params["tag"]))

    activities =
      ActivityPub.fetch_public_activities(params)
      |> Enum.reverse()

    conn
    |> add_link_headers(:hashtag_timeline, activities, params["tag"], %{"local" => local_only})
    |> render(StatusView, "index.json", %{activities: activities, for: user, as: :activity})
  end

  # TODO: Pagination
  def followers(conn, %{"id" => id}) do
    with %User{} = user <- Repo.get(User, id),
         {:ok, followers} <- User.get_followers(user) do
      render(conn, AccountView, "accounts.json", %{users: followers, as: :user})
    end
  end

  def following(conn, %{"id" => id}) do
    with %User{} = user <- Repo.get(User, id),
         {:ok, followers} <- User.get_friends(user) do
      render(conn, AccountView, "accounts.json", %{users: followers, as: :user})
    end
  end

  def follow_requests(%{assigns: %{user: followed}} = conn, _params) do
    with {:ok, follow_requests} <- User.get_follow_requests(followed) do
      render(conn, AccountView, "accounts.json", %{users: follow_requests, as: :user})
    end
  end

  def authorize_follow_request(%{assigns: %{user: followed}} = conn, %{"id" => id}) do
    with %User{} = follower <- Repo.get(User, id),
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
      render(conn, AccountView, "relationship.json", %{user: followed, target: follower})
    else
      {:error, message} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Jason.encode!(%{"error" => message}))
    end
  end

  def reject_follow_request(%{assigns: %{user: followed}} = conn, %{"id" => id}) do
    with %User{} = follower <- Repo.get(User, id),
         %Activity{} = follow_activity <- Utils.fetch_latest_follow(follower, followed),
         {:ok, follow_activity} <- Utils.update_follow_state(follow_activity, "reject"),
         {:ok, _activity} <-
           ActivityPub.reject(%{
             to: [follower.ap_id],
             actor: followed.ap_id,
             object: follow_activity.data["id"],
             type: "Reject"
           }) do
      render(conn, AccountView, "relationship.json", %{user: followed, target: follower})
    else
      {:error, message} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Jason.encode!(%{"error" => message}))
    end
  end

  def follow(%{assigns: %{user: follower}} = conn, %{"id" => id}) do
    with %User{} = followed <- Repo.get(User, id),
         {:ok, follower} <- User.maybe_direct_follow(follower, followed),
         {:ok, _activity} <- ActivityPub.follow(follower, followed),
         {:ok, follower, followed} <-
           User.wait_and_refresh(
             Pleroma.Config.get([:activitypub, :follow_handshake_timeout]),
             follower,
             followed
           ) do
      render(conn, AccountView, "relationship.json", %{user: follower, target: followed})
    else
      {:error, message} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Jason.encode!(%{"error" => message}))
    end
  end

  def follow(%{assigns: %{user: follower}} = conn, %{"uri" => uri}) do
    with %User{} = followed <- Repo.get_by(User, nickname: uri),
         {:ok, follower} <- User.maybe_direct_follow(follower, followed),
         {:ok, _activity} <- ActivityPub.follow(follower, followed) do
      render(conn, AccountView, "account.json", %{user: followed, for: follower})
    else
      {:error, message} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Jason.encode!(%{"error" => message}))
    end
  end

  def unfollow(%{assigns: %{user: follower}} = conn, %{"id" => id}) do
    with %User{} = followed <- Repo.get(User, id),
         {:ok, _activity} <- ActivityPub.unfollow(follower, followed),
         {:ok, follower, _} <- User.unfollow(follower, followed) do
      render(conn, AccountView, "relationship.json", %{user: follower, target: followed})
    end
  end

  def block(%{assigns: %{user: blocker}} = conn, %{"id" => id}) do
    with %User{} = blocked <- Repo.get(User, id),
         {:ok, blocker} <- User.block(blocker, blocked),
         {:ok, _activity} <- ActivityPub.block(blocker, blocked) do
      render(conn, AccountView, "relationship.json", %{user: blocker, target: blocked})
    else
      {:error, message} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Jason.encode!(%{"error" => message}))
    end
  end

  def unblock(%{assigns: %{user: blocker}} = conn, %{"id" => id}) do
    with %User{} = blocked <- Repo.get(User, id),
         {:ok, blocker} <- User.unblock(blocker, blocked),
         {:ok, _activity} <- ActivityPub.unblock(blocker, blocked) do
      render(conn, AccountView, "relationship.json", %{user: blocker, target: blocked})
    else
      {:error, message} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Jason.encode!(%{"error" => message}))
    end
  end

  # TODO: Use proper query
  def blocks(%{assigns: %{user: user}} = conn, _) do
    with blocked_users <- user.info.blocks || [],
         accounts <- Enum.map(blocked_users, fn ap_id -> User.get_cached_by_ap_id(ap_id) end) do
      res = AccountView.render("accounts.json", users: accounts, for: user, as: :user)
      json(conn, res)
    end
  end

  def domain_blocks(%{assigns: %{user: %{info: info}}} = conn, _) do
    json(conn, info.domain_blocks || [])
  end

  def block_domain(%{assigns: %{user: blocker}} = conn, %{"domain" => domain}) do
    User.block_domain(blocker, domain)
    json(conn, %{})
  end

  def unblock_domain(%{assigns: %{user: blocker}} = conn, %{"domain" => domain}) do
    User.unblock_domain(blocker, domain)
    json(conn, %{})
  end

  def status_search(query) do
    fetched =
      if Regex.match?(~r/https?:/, query) do
        with {:ok, object} <- ActivityPub.fetch_object_from_id(query) do
          [Activity.get_create_activity_by_object_ap_id(object.data["id"])]
        else
          _e -> []
        end
      end || []

    q =
      from(
        a in Activity,
        where: fragment("?->>'type' = 'Create'", a.data),
        where: "https://www.w3.org/ns/activitystreams#Public" in a.recipients,
        where:
          fragment(
            "to_tsvector('english', ?->'object'->>'content') @@ plainto_tsquery('english', ?)",
            a.data,
            ^query
          ),
        limit: 20,
        order_by: [desc: :id]
      )

    Repo.all(q) ++ fetched
  end

  def search2(%{assigns: %{user: user}} = conn, %{"q" => query} = params) do
    accounts = User.search(query, params["resolve"] == "true")

    statuses = status_search(query)

    tags_path = Web.base_url() <> "/tag/"

    tags =
      String.split(query)
      |> Enum.uniq()
      |> Enum.filter(fn tag -> String.starts_with?(tag, "#") end)
      |> Enum.map(fn tag -> String.slice(tag, 1..-1) end)
      |> Enum.map(fn tag -> %{name: tag, url: tags_path <> tag} end)

    res = %{
      "accounts" => AccountView.render("accounts.json", users: accounts, for: user, as: :user),
      "statuses" =>
        StatusView.render("index.json", activities: statuses, for: user, as: :activity),
      "hashtags" => tags
    }

    json(conn, res)
  end

  def search(%{assigns: %{user: user}} = conn, %{"q" => query} = params) do
    accounts = User.search(query, params["resolve"] == "true")

    statuses = status_search(query)

    tags =
      String.split(query)
      |> Enum.uniq()
      |> Enum.filter(fn tag -> String.starts_with?(tag, "#") end)
      |> Enum.map(fn tag -> String.slice(tag, 1..-1) end)

    res = %{
      "accounts" => AccountView.render("accounts.json", users: accounts, for: user, as: :user),
      "statuses" =>
        StatusView.render("index.json", activities: statuses, for: user, as: :activity),
      "hashtags" => tags
    }

    json(conn, res)
  end

  def account_search(%{assigns: %{user: user}} = conn, %{"q" => query} = params) do
    accounts = User.search(query, params["resolve"] == "true")

    res = AccountView.render("accounts.json", users: accounts, for: user, as: :user)

    json(conn, res)
  end

  def favourites(%{assigns: %{user: user}} = conn, _) do
    params =
      %{}
      |> Map.put("type", "Create")
      |> Map.put("favorited_by", user.ap_id)
      |> Map.put("blocking_user", user)

    activities =
      ActivityPub.fetch_public_activities(params)
      |> Enum.reverse()

    conn
    |> render(StatusView, "index.json", %{activities: activities, for: user, as: :activity})
  end

  def get_lists(%{assigns: %{user: user}} = conn, opts) do
    lists = Pleroma.List.for_user(user, opts)
    res = ListView.render("lists.json", lists: lists)
    json(conn, res)
  end

  def get_list(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %Pleroma.List{} = list <- Pleroma.List.get(id, user) do
      res = ListView.render("list.json", list: list)
      json(conn, res)
    else
      _e -> json(conn, "error")
    end
  end

  def account_lists(%{assigns: %{user: user}} = conn, %{"id" => account_id}) do
    lists = Pleroma.List.get_lists_account_belongs(user, account_id)
    res = ListView.render("lists.json", lists: lists)
    json(conn, res)
  end

  def delete_list(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %Pleroma.List{} = list <- Pleroma.List.get(id, user),
         {:ok, _list} <- Pleroma.List.delete(list) do
      json(conn, %{})
    else
      _e ->
        json(conn, "error")
    end
  end

  def create_list(%{assigns: %{user: user}} = conn, %{"title" => title}) do
    with {:ok, %Pleroma.List{} = list} <- Pleroma.List.create(title, user) do
      res = ListView.render("list.json", list: list)
      json(conn, res)
    end
  end

  def add_to_list(%{assigns: %{user: user}} = conn, %{"id" => id, "account_ids" => accounts}) do
    accounts
    |> Enum.each(fn account_id ->
      with %Pleroma.List{} = list <- Pleroma.List.get(id, user),
           %User{} = followed <- Repo.get(User, account_id) do
        Pleroma.List.follow(list, followed)
      end
    end)

    json(conn, %{})
  end

  def remove_from_list(%{assigns: %{user: user}} = conn, %{"id" => id, "account_ids" => accounts}) do
    accounts
    |> Enum.each(fn account_id ->
      with %Pleroma.List{} = list <- Pleroma.List.get(id, user),
           %User{} = followed <- Repo.get(Pleroma.User, account_id) do
        Pleroma.List.unfollow(list, followed)
      end
    end)

    json(conn, %{})
  end

  def list_accounts(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %Pleroma.List{} = list <- Pleroma.List.get(id, user),
         {:ok, users} = Pleroma.List.get_following(list) do
      render(conn, AccountView, "accounts.json", %{users: users, as: :user})
    end
  end

  def rename_list(%{assigns: %{user: user}} = conn, %{"id" => id, "title" => title}) do
    with %Pleroma.List{} = list <- Pleroma.List.get(id, user),
         {:ok, list} <- Pleroma.List.rename(list, title) do
      res = ListView.render("list.json", list: list)
      json(conn, res)
    else
      _e ->
        json(conn, "error")
    end
  end

  def list_timeline(%{assigns: %{user: user}} = conn, %{"list_id" => id} = params) do
    with %Pleroma.List{title: title, following: following} <- Pleroma.List.get(id, user) do
      params =
        params
        |> Map.put("type", "Create")
        |> Map.put("blocking_user", user)

      # we must filter the following list for the user to avoid leaking statuses the user
      # does not actually have permission to see (for more info, peruse security issue #270).
      following_to =
        following
        |> Enum.filter(fn x -> x in user.following end)

      activities =
        ActivityPub.fetch_activities_bounded(following_to, following, params)
        |> Enum.reverse()

      conn
      |> render(StatusView, "index.json", %{activities: activities, for: user, as: :activity})
    else
      _e ->
        conn
        |> put_status(403)
        |> json(%{error: "Error."})
    end
  end

  def index(%{assigns: %{user: user}} = conn, _params) do
    token =
      conn
      |> get_session(:oauth_token)

    if user && token do
      mastodon_emoji = mastodonized_emoji()

      limit = Pleroma.Config.get([:instance, :limit])

      accounts =
        Map.put(%{}, user.id, AccountView.render("account.json", %{user: user, for: user}))

      initial_state =
        %{
          meta: %{
            streaming_api_base_url:
              String.replace(Pleroma.Web.Endpoint.static_url(), "http", "ws"),
            access_token: token,
            locale: "en",
            domain: Pleroma.Web.Endpoint.host(),
            admin: "1",
            me: "#{user.id}",
            unfollow_modal: false,
            boost_modal: false,
            delete_modal: true,
            auto_play_gif: false,
            display_sensitive_media: false,
            reduce_motion: false,
            max_toot_chars: limit
          },
          rights: %{
            delete_others_notice: !!user.info.is_moderator
          },
          compose: %{
            me: "#{user.id}",
            default_privacy: user.info.default_scope,
            default_sensitive: false
          },
          media_attachments: %{
            accept_content_types: [
              ".jpg",
              ".jpeg",
              ".png",
              ".gif",
              ".webm",
              ".mp4",
              ".m4v",
              "image\/jpeg",
              "image\/png",
              "image\/gif",
              "video\/webm",
              "video\/mp4"
            ]
          },
          settings:
            Map.get(user.info, :settings) ||
              %{
                onboarded: true,
                home: %{
                  shows: %{
                    reblog: true,
                    reply: true
                  }
                },
                notifications: %{
                  alerts: %{
                    follow: true,
                    favourite: true,
                    reblog: true,
                    mention: true
                  },
                  shows: %{
                    follow: true,
                    favourite: true,
                    reblog: true,
                    mention: true
                  },
                  sounds: %{
                    follow: true,
                    favourite: true,
                    reblog: true,
                    mention: true
                  }
                }
              },
          push_subscription: nil,
          accounts: accounts,
          custom_emojis: mastodon_emoji,
          char_limit: limit
        }
        |> Jason.encode!()

      conn
      |> put_layout(false)
      |> render(MastodonView, "index.html", %{initial_state: initial_state})
    else
      conn
      |> redirect(to: "/web/login")
    end
  end

  def put_settings(%{assigns: %{user: user}} = conn, %{"data" => settings} = _params) do
    with new_info <- Map.put(user.info, "settings", settings),
         change <- User.info_changeset(user, %{info: new_info}),
         {:ok, _user} <- User.update_and_set_cache(change) do
      conn
      |> json(%{})
    else
      e ->
        conn
        |> json(%{error: inspect(e)})
    end
  end

  def login(conn, %{"code" => code}) do
    with {:ok, app} <- get_or_make_app(),
         %Authorization{} = auth <- Repo.get_by(Authorization, token: code, app_id: app.id),
         {:ok, token} <- Token.exchange_token(app, auth) do
      conn
      |> put_session(:oauth_token, token.token)
      |> redirect(to: "/web/getting-started")
    end
  end

  def login(conn, _) do
    with {:ok, app} <- get_or_make_app() do
      path =
        o_auth_path(conn, :authorize,
          response_type: "code",
          client_id: app.client_id,
          redirect_uri: ".",
          scope: app.scopes
        )

      conn
      |> redirect(to: path)
    end
  end

  defp get_or_make_app() do
    with %App{} = app <- Repo.get_by(App, client_name: "Mastodon-Local") do
      {:ok, app}
    else
      _e ->
        cs =
          App.register_changeset(%App{}, %{
            client_name: "Mastodon-Local",
            redirect_uris: ".",
            scopes: "read,write,follow"
          })

        Repo.insert(cs)
    end
  end

  def logout(conn, _) do
    conn
    |> clear_session
    |> redirect(to: "/")
  end

  def relationship_noop(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    Logger.debug("Unimplemented, returning unmodified relationship")

    with %User{} = target <- Repo.get(User, id) do
      render(conn, AccountView, "relationship.json", %{user: user, target: target})
    end
  end

  def empty_array(conn, _) do
    Logger.debug("Unimplemented, returning an empty array")
    json(conn, [])
  end

  def empty_object(conn, _) do
    Logger.debug("Unimplemented, returning an empty object")
    json(conn, %{})
  end

  def render_notification(user, %{id: id, activity: activity, inserted_at: created_at} = _params) do
    actor = User.get_cached_by_ap_id(activity.data["actor"])

    created_at =
      NaiveDateTime.to_iso8601(created_at)
      |> String.replace(~r/(\.\d+)?$/, ".000Z", global: false)

    id = id |> to_string

    case activity.data["type"] do
      "Create" ->
        %{
          id: id,
          type: "mention",
          created_at: created_at,
          account: AccountView.render("account.json", %{user: actor, for: user}),
          status: StatusView.render("status.json", %{activity: activity, for: user})
        }

      "Like" ->
        liked_activity = Activity.get_create_activity_by_object_ap_id(activity.data["object"])

        %{
          id: id,
          type: "favourite",
          created_at: created_at,
          account: AccountView.render("account.json", %{user: actor, for: user}),
          status: StatusView.render("status.json", %{activity: liked_activity, for: user})
        }

      "Announce" ->
        announced_activity = Activity.get_create_activity_by_object_ap_id(activity.data["object"])

        %{
          id: id,
          type: "reblog",
          created_at: created_at,
          account: AccountView.render("account.json", %{user: actor, for: user}),
          status: StatusView.render("status.json", %{activity: announced_activity, for: user})
        }

      "Follow" ->
        %{
          id: id,
          type: "follow",
          created_at: created_at,
          account: AccountView.render("account.json", %{user: actor, for: user})
        }

      _ ->
        nil
    end
  end

  def get_filters(%{assigns: %{user: user}} = conn, _) do
    filters = Pleroma.Filter.get_filters(user)
    res = FilterView.render("filters.json", filters: filters)
    json(conn, res)
  end

  def create_filter(
        %{assigns: %{user: user}} = conn,
        %{"phrase" => phrase, "context" => context} = params
      ) do
    query = %Pleroma.Filter{
      user_id: user.id,
      phrase: phrase,
      context: context,
      hide: Map.get(params, "irreversible", nil),
      whole_word: Map.get(params, "boolean", true)
      # expires_at
    }

    {:ok, response} = Pleroma.Filter.create(query)
    res = FilterView.render("filter.json", filter: response)
    json(conn, res)
  end

  def get_filter(%{assigns: %{user: user}} = conn, %{"id" => filter_id}) do
    filter = Pleroma.Filter.get(filter_id, user)
    res = FilterView.render("filter.json", filter: filter)
    json(conn, res)
  end

  def update_filter(
        %{assigns: %{user: user}} = conn,
        %{"phrase" => phrase, "context" => context, "id" => filter_id} = params
      ) do
    query = %Pleroma.Filter{
      user_id: user.id,
      filter_id: filter_id,
      phrase: phrase,
      context: context,
      hide: Map.get(params, "irreversible", nil),
      whole_word: Map.get(params, "boolean", true)
      # expires_at
    }

    {:ok, response} = Pleroma.Filter.update(query)
    res = FilterView.render("filter.json", filter: response)
    json(conn, res)
  end

  def delete_filter(%{assigns: %{user: user}} = conn, %{"id" => filter_id}) do
    query = %Pleroma.Filter{
      user_id: user.id,
      filter_id: filter_id
    }

    {:ok, _} = Pleroma.Filter.delete(query)
    json(conn, %{})
  end

  def errors(conn, _) do
    conn
    |> put_status(500)
    |> json("Something went wrong")
  end

  def suggestions(%{assigns: %{user: user}} = conn, _) do
    suggestions = Pleroma.Config.get(:suggestions)

    if Keyword.get(suggestions, :enabled, false) do
      api = Keyword.get(suggestions, :third_party_engine, "")
      timeout = Keyword.get(suggestions, :timeout, 5000)
      limit = Keyword.get(suggestions, :limit, 23)

      host = Pleroma.Config.get([Pleroma.Web.Endpoint, :url, :host])

      user = user.nickname
      url = String.replace(api, "{{host}}", host) |> String.replace("{{user}}", user)

      with {:ok, %{status_code: 200, body: body}} <-
             @httpoison.get(url, [], timeout: timeout, recv_timeout: timeout),
           {:ok, data} <- Jason.decode(body) do
        data2 =
          Enum.slice(data, 0, limit)
          |> Enum.map(fn x ->
            Map.put(
              x,
              "id",
              case User.get_or_fetch(x["acct"]) do
                %{id: id} -> id
                _ -> 0
              end
            )
          end)
          |> Enum.map(fn x ->
            Map.put(x, "avatar", MediaProxy.url(x["avatar"]))
          end)
          |> Enum.map(fn x ->
            Map.put(x, "avatar_static", MediaProxy.url(x["avatar_static"]))
          end)

        conn
        |> json(data2)
      else
        e -> Logger.error("Could not retrieve suggestions at fetch #{url}, #{inspect(e)}")
      end
    else
      json(conn, [])
    end
  end

  def try_render(conn, renderer, target, params)
      when is_binary(target) do
    res = render(conn, renderer, target, params)

    if res == nil do
      conn
      |> put_status(501)
      |> json(%{error: "Can't display this activity"})
    else
      res
    end
  end

  def try_render(conn, _, _, _) do
    conn
    |> put_status(501)
    |> json(%{error: "Can't display this activity"})
  end
end
