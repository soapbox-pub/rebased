defmodule Pleroma.Web.MastodonAPI.MastodonAPIController do
  use Pleroma.Web, :controller
  alias Pleroma.{Repo, Activity, User, Notification, Stats}
  alias Pleroma.Web
  alias Pleroma.Web.MastodonAPI.{StatusView, AccountView, MastodonView}
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.{CommonAPI, OStatus}
  alias Pleroma.Web.OAuth.{Authorization, Token, App}
  alias Comeonin.Pbkdf2
  import Ecto.Query
  require Logger

  def create_app(conn, params) do
    with cs <- App.register_changeset(%App{}, params) |> IO.inspect,
         {:ok, app} <- Repo.insert(cs) |> IO.inspect do
      res = %{
        id: app.id,
        client_id: app.client_id,
        client_secret: app.client_secret
      }

      json(conn, res)
    end
  end

  def update_credentials(%{assigns: %{user: user}} = conn, params) do
    original_user = user
    params = if bio = params["note"] do
      Map.put(params, "bio", bio)
    else
      params
    end

    params = if name = params["display_name"] do
      Map.put(params, "name", name)
    else
      params
    end

    user = if avatar = params["avatar"] do
      with %Plug.Upload{} <- avatar,
           {:ok, object} <- ActivityPub.upload(avatar),
           change = Ecto.Changeset.change(user, %{avatar: object.data}),
           {:ok, user} = User.update_and_set_cache(change) do
        user
      else
        _e -> user
      end
    else
      user
    end

    user = if banner = params["header"] do
      with %Plug.Upload{} <- banner,
           {:ok, object} <- ActivityPub.upload(banner),
           new_info <- Map.put(user.info, "banner", object.data),
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
      if original_user != user do
        CommonAPI.update(user)
      end
      json conn, AccountView.render("account.json", %{user: user})
    else
      _e ->
        conn
        |> put_status(403)
        |> json(%{error: "Invalid request"})
    end
  end

  def verify_credentials(%{assigns: %{user: user}} = conn, _) do
    account = AccountView.render("account.json", %{user: user})
    json(conn, account)
  end

  def user(conn, %{"id" => id}) do
    with %User{} = user <- Repo.get(User, id) do
      account = AccountView.render("account.json", %{user: user})
      json(conn, account)
    else
      _e -> conn
      |> put_status(404)
      |> json(%{error: "Can't find user"})
    end
  end

  @instance Application.get_env(:pleroma, :instance)

  def masto_instance(conn, _params) do
    response = %{
      uri: Web.base_url,
      title: Keyword.get(@instance, :name),
      description: "A Pleroma instance, an alternative fediverse server",
      version: Keyword.get(@instance, :version),
      email: Keyword.get(@instance, :email),
      urls: %{
        streaming_api: String.replace(Web.base_url, ["http","https"], "wss")
      },
      stats: Stats.get_stats,
      thumbnail: Web.base_url <> "/instance/thumbnail.jpeg",
      max_toot_chars: Keyword.get(@instance, :limit)
    }

    json(conn, response)
  end

  def peers(conn, _params) do
    json(conn, Stats.get_peers)
  end

  defp mastodonized_emoji do
    Pleroma.Formatter.get_custom_emoji()
    |> Enum.map(fn {shortcode, relative_url} ->
      url = to_string URI.merge(Web.base_url(), relative_url)
      %{
        "shortcode" => shortcode,
        "static_url" => url,
        "url" => url
      }
    end)
  end

  def custom_emojis(conn, _params) do
    mastodon_emoji = mastodonized_emoji()
    json conn, mastodon_emoji
  end

  defp add_link_headers(conn, method, activities, param \\ false) do
    last = List.last(activities)
    first = List.first(activities)
    if last do
      min = last.id
      max = first.id
      {next_url, prev_url} = if param do
        {
          mastodon_api_url(Pleroma.Web.Endpoint, method, param, max_id: min),
          mastodon_api_url(Pleroma.Web.Endpoint, method, param, since_id: max)
        }
      else
        {
          mastodon_api_url(Pleroma.Web.Endpoint, method, max_id: min),
          mastodon_api_url(Pleroma.Web.Endpoint, method, since_id: max)
        }
      end
      conn
      |> put_resp_header("link", "<#{next_url}>; rel=\"next\", <#{prev_url}>; rel=\"prev\"")
    else
      conn
    end
  end

  def home_timeline(%{assigns: %{user: user}} = conn, params) do
    params = params
    |> Map.put("type", ["Create", "Announce"])
    |> Map.put("blocking_user", user)
    |> Map.put("user", user)

    activities = ActivityPub.fetch_activities([user.ap_id | user.following], params)
    |> Enum.reverse

    conn
    |> add_link_headers(:home_timeline, activities)
    |> render(StatusView, "index.json", %{activities: activities, for: user, as: :activity})
  end

  def public_timeline(%{assigns: %{user: user}} = conn, params) do
    params = params
    |> Map.put("type", ["Create", "Announce"])
    |> Map.put("local_only", params["local"] in [true, "True", "true", "1"])
    |> Map.put("blocking_user", user)

    activities = ActivityPub.fetch_public_activities(params)
    |> Enum.reverse

    conn
    |> add_link_headers(:public_timeline, activities)
    |> render(StatusView, "index.json", %{activities: activities, for: user, as: :activity})
  end

  def user_statuses(%{assigns: %{user: user}} = conn, params) do
    with %User{ap_id: ap_id} <- Repo.get(User, params["id"]) do
      params = params
      |> Map.put("type", ["Create", "Announce"])
      |> Map.put("actor_id", ap_id)
      |> Map.put("whole_db", true)

      activities = ActivityPub.fetch_public_activities(params)
      |> Enum.reverse

      conn
      |> add_link_headers(:user_statuses, activities, params["id"])
      |> render(StatusView, "index.json", %{activities: activities, for: user, as: :activity})
    end
  end

  def get_status(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %Activity{} = activity <- Repo.get(Activity, id),
         true <- ActivityPub.visible_for_user?(activity, user) do
      render conn, StatusView, "status.json", %{activity: activity, for: user}
    end
  end

  def get_context(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %Activity{} = activity <- Repo.get(Activity, id),
         activities <- ActivityPub.fetch_activities_for_context(activity.data["context"], %{"blocking_user" => user, "user" => user}),
         activities <- activities |> Enum.filter(fn (%{id: aid}) -> to_string(aid) != to_string(id) end),
         activities <- activities |> Enum.filter(fn (%{data: %{"type" => type}}) -> type == "Create" end),
         grouped_activities <- Enum.group_by(activities, fn (%{id: id}) -> id < activity.id end) do
      result = %{
        ancestors: StatusView.render("index.json", for: user, activities: grouped_activities[true] || [], as: :activity) |> Enum.reverse,
        descendants: StatusView.render("index.json", for: user, activities: grouped_activities[false] || [], as: :activity) |> Enum.reverse,
      }

      json(conn, result)
    end
  end

  def post_status(%{assigns: %{user: user}} = conn, %{"status" => _} = params) do
    params = params
    |> Map.put("in_reply_to_status_id", params["in_reply_to_id"])
    |> Map.put("no_attachment_links", true)

    {:ok, activity} = CommonAPI.post(user, params)
    render conn, StatusView, "status.json", %{activity: activity, for: user, as: :activity}
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
    with {:ok, announce, _activity} = CommonAPI.repeat(ap_id_or_id, user) do
      render conn, StatusView, "status.json", %{activity: announce, for: user, as: :activity}
    end
  end

  def fav_status(%{assigns: %{user: user}} = conn, %{"id" => ap_id_or_id}) do
    with {:ok, _fav, %{data: %{"id" => id}}} = CommonAPI.favorite(ap_id_or_id, user),
         %Activity{} = activity <- Activity.get_create_activity_by_object_ap_id(id) do
      render conn, StatusView, "status.json", %{activity: activity, for: user, as: :activity}
    end
  end

  def unfav_status(%{assigns: %{user: user}} = conn, %{"id" => ap_id_or_id}) do
    with {:ok, %{data: %{"id" => id}}} = CommonAPI.unfavorite(ap_id_or_id, user),
         %Activity{} = activity <- Activity.get_create_activity_by_object_ap_id(id) do
      render conn, StatusView, "status.json", %{activity: activity, for: user, as: :activity}
    end
  end

  def notifications(%{assigns: %{user: user}} = conn, params) do
    notifications = Notification.for_user(user, params)
    result = Enum.map(notifications, fn x ->
      render_notification(user, x)
    end)
    |> Enum.filter(&(&1))

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
        |> send_resp(403, Poison.encode!(%{"error" => reason}))
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
        |> send_resp(403, Poison.encode!(%{"error" => reason}))
    end
  end

  def relationships(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    id = List.wrap(id)
    q = from u in User,
      where: u.id in ^id
    targets = Repo.all(q)
    render conn, AccountView, "relationships.json", %{user: user, targets: targets}
  end

  def upload(%{assigns: %{user: _}} = conn, %{"file" => file}) do
    with {:ok, object} <- ActivityPub.upload(file) do
      data = object.data
      |> Map.put("id", object.id)

      render conn, StatusView, "attachment.json", %{attachment: data}
    end
  end

  def favourited_by(conn, %{"id" => id}) do
    with %Activity{data: %{"object" => %{"likes" => likes}}} <- Repo.get(Activity, id) do
      q = from u in User,
        where: u.ap_id in ^likes
      users = Repo.all(q)
      render conn, AccountView, "accounts.json", %{users: users, as: :user}
    else
      _ -> json(conn, [])
    end
  end

  def reblogged_by(conn, %{"id" => id}) do
    with %Activity{data: %{"object" => %{"announcements" => announces}}} <- Repo.get(Activity, id) do
      q = from u in User,
        where: u.ap_id in ^announces
      users = Repo.all(q)
      render conn, AccountView, "accounts.json", %{users: users, as: :user}
    else
      _ -> json(conn, [])
    end
  end

  def hashtag_timeline(%{assigns: %{user: user}} = conn, params) do
    params = params
    |> Map.put("type", "Create")
    |> Map.put("local_only", !!params["local"])
    |> Map.put("blocking_user", user)

    activities = ActivityPub.fetch_public_activities(params)
    |> Enum.reverse

    conn
    |> add_link_headers(:hashtag_timeline, activities, params["tag"])
    |> render(StatusView, "index.json", %{activities: activities, for: user, as: :activity})
  end

  # TODO: Pagination
  def followers(conn, %{"id" => id}) do
    with %User{} = user <- Repo.get(User, id),
         {:ok, followers} <- User.get_followers(user) do
      render conn, AccountView, "accounts.json", %{users: followers, as: :user}
    end
  end

  def following(conn, %{"id" => id}) do
    with %User{} = user <- Repo.get(User, id),
         {:ok, followers} <- User.get_friends(user) do
      render conn, AccountView, "accounts.json", %{users: followers, as: :user}
    end
  end

  def follow(%{assigns: %{user: follower}} = conn, %{"id" => id}) do
    with %User{} = followed <- Repo.get(User, id),
         {:ok, follower} <- User.follow(follower, followed),
         {:ok, _activity} <- ActivityPub.follow(follower, followed) do
      render conn, AccountView, "relationship.json", %{user: follower, target: followed}
    else
      {:error, message} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Poison.encode!(%{"error" => message}))
    end
  end

  def follow(%{assigns: %{user: follower}} = conn, %{"uri" => uri}) do
    with %User{} = followed <- Repo.get_by(User, nickname: uri),
         {:ok, follower} <- User.follow(follower, followed),
         {:ok, _activity} <- ActivityPub.follow(follower, followed) do
      render conn, AccountView, "account.json", %{user: followed}
    else
      {:error, message} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Poison.encode!(%{"error" => message}))
    end
  end

  # TODO: Clean up and unify
  def unfollow(%{assigns: %{user: follower}} = conn, %{"id" => id}) do
    with %User{} = followed <- Repo.get(User, id),
         { :ok, follower, follow_activity } <- User.unfollow(follower, followed),
         { :ok, _activity } <- ActivityPub.insert(%{
           "type" => "Undo",
           "actor" => follower.ap_id,
           "object" => follow_activity.data["id"] # get latest Follow for these users
         }) do
      render conn, AccountView, "relationship.json", %{user: follower, target: followed}
    end
  end

  def block(%{assigns: %{user: blocker}} = conn, %{"id" => id}) do
    with %User{} = blocked <- Repo.get(User, id),
         {:ok, blocker} <- User.block(blocker, blocked) do
      render conn, AccountView, "relationship.json", %{user: blocker, target: blocked}
    else
      {:error, message} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Poison.encode!(%{"error" => message}))
    end
  end

  def unblock(%{assigns: %{user: blocker}} = conn, %{"id" => id}) do
    with %User{} = blocked <- Repo.get(User, id),
         {:ok, blocker} <- User.unblock(blocker, blocked) do
      render conn, AccountView, "relationship.json", %{user: blocker, target: blocked}
    else
      {:error, message} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Poison.encode!(%{"error" => message}))
    end
  end

  # TODO: Use proper query
  def blocks(%{assigns: %{user: user}} = conn, _) do
    with blocked_users <- user.info["blocks"] || [],
         accounts <- Enum.map(blocked_users, fn (ap_id) -> User.get_cached_by_ap_id(ap_id) end) do
      res = AccountView.render("accounts.json", users: accounts, for: user, as: :user)
      json(conn, res)
    end
  end

  def search(%{assigns: %{user: user}} = conn, %{"q" => query} = params) do
    accounts = User.search(query, params["resolve"] == "true")

    fetched = if Regex.match?(~r/https?:/, query) do
      with {:ok, activities} <- OStatus.fetch_activity_from_url(query) do
        activities
      else
        _e -> []
      end
    end || []

    q = from a in Activity,
      where: fragment("?->>'type' = 'Create'", a.data),
      where: fragment("to_tsvector('english', ?->'object'->>'content') @@ plainto_tsquery('english', ?)", a.data, ^query),
      limit: 20
    statuses = Repo.all(q) ++ fetched

    res = %{
      "accounts" => AccountView.render("accounts.json", users: accounts, for: user, as: :user),
      "statuses" => StatusView.render("index.json", activities: statuses, for: user, as: :activity),
      "hashtags" => []
    }

    json(conn, res)
  end

  def account_search(%{assigns: %{user: user}} = conn, %{"q" => query} = params) do
    accounts = User.search(query, params["resolve"] == "true")

    res = AccountView.render("accounts.json", users: accounts, for: user, as: :user)

    json(conn, res)
  end

  def favourites(%{assigns: %{user: user}} = conn, _) do
    params = %{}
    |> Map.put("type", "Create")
    |> Map.put("favorited_by", user.ap_id)
    |> Map.put("blocking_user", user)

    activities = ActivityPub.fetch_public_activities(params)
    |> Enum.reverse

    conn
    |> render(StatusView, "index.json", %{activities: activities, for: user, as: :activity})
  end

  def index(%{assigns: %{user: user}} = conn, _params) do
    token = conn
    |> get_session(:oauth_token)

    if user && token do
      mastodon_emoji = mastodonized_emoji()
      accounts = Map.put(%{}, user.id, AccountView.render("account.json", %{user: user}))
      initial_state = %{
        meta: %{
          streaming_api_base_url: String.replace(Pleroma.Web.Endpoint.static_url(), "http", "ws"),
          access_token: token,
          locale: "en",
          domain: Pleroma.Web.Endpoint.host(),
          admin: "1",
          me: "#{user.id}",
          unfollow_modal: false,
          boost_modal: false,
          delete_modal: true,
          auto_play_gif: false,
          reduce_motion: false
        },
        compose: %{
          me: "#{user.id}",
          default_privacy: "public",
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
        settings: %{
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
        custom_emojis: mastodon_emoji
      } |> Poison.encode!
      conn
      |> put_layout(false)
      |> render(MastodonView, "index.html", %{initial_state: initial_state})
    else
      conn
      |> redirect(to: "/web/login")
    end
  end

  def login(conn, _) do
    conn
    |> render(MastodonView, "login.html", %{error: false})
  end

  defp get_or_make_app() do
    with %App{} = app <- Repo.get_by(App, client_name: "Mastodon-Local") do
      {:ok, app}
    else
      _e ->
        cs = App.register_changeset(%App{}, %{client_name: "Mastodon-Local", redirect_uris: ".", scopes: "read,write,follow"})
        Repo.insert(cs)
    end
  end

  def login_post(conn, %{"authorization" => %{ "name" => name, "password" => password}}) do
    with %User{} = user <- User.get_cached_by_nickname(name),
         true <- Pbkdf2.checkpw(password, user.password_hash),
         {:ok, app} <- get_or_make_app(),
         {:ok, auth} <- Authorization.create_authorization(app, user),
         {:ok, token} <- Token.exchange_token(app, auth) do
      conn
      |> put_session(:oauth_token, token.token)
      |> redirect(to: "/web/getting-started")
    else
      _e ->
        conn
        |> render(MastodonView, "login.html", %{error: "Wrong username or password"})
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
      render conn, AccountView, "relationship.json", %{user: user, target: target}
    end
  end

  def empty_array(conn, _) do
    Logger.debug("Unimplemented, returning an empty array")
    json(conn, [])
  end

  def render_notification(user, %{id: id, activity: activity, inserted_at: created_at} = _params) do
    actor = User.get_cached_by_ap_id(activity.data["actor"])
    created_at = NaiveDateTime.to_iso8601(created_at)
    |> String.replace(~r/(\.\d+)?$/, ".000Z", global: false)
    case activity.data["type"] do
      "Create" ->
        %{id: id, type: "mention", created_at: created_at, account: AccountView.render("account.json", %{user: actor}), status: StatusView.render("status.json", %{activity: activity, for: user})}
      "Like" ->
        liked_activity = Activity.get_create_activity_by_object_ap_id(activity.data["object"])
        %{id: id, type: "favourite", created_at: created_at, account: AccountView.render("account.json", %{user: actor}), status: StatusView.render("status.json", %{activity: liked_activity, for: user})}
      "Announce" ->
        announced_activity = Activity.get_create_activity_by_object_ap_id(activity.data["object"])
        %{id: id, type: "reblog", created_at: created_at, account: AccountView.render("account.json", %{user: actor}), status: StatusView.render("status.json", %{activity: announced_activity, for: user})}
      "Follow" ->
        %{id: id, type: "follow", created_at: created_at, account: AccountView.render("account.json", %{user: actor})}
      _ -> nil
    end
  end
end
