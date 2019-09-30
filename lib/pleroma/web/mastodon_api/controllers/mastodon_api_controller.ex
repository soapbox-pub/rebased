# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MastodonAPIController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [add_link_headers: 2]

  alias Pleroma.Activity
  alias Pleroma.Bookmark
  alias Pleroma.Config
  alias Pleroma.HTTP
  alias Pleroma.Object
  alias Pleroma.Pagination
  alias Pleroma.Plugs.RateLimiter
  alias Pleroma.Repo
  alias Pleroma.Stats
  alias Pleroma.User
  alias Pleroma.Web
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.AppView
  alias Pleroma.Web.MastodonAPI.MastodonView
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.MediaProxy
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Authorization
  alias Pleroma.Web.OAuth.Scopes
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.TwitterAPI.TwitterAPI

  require Logger

  plug(RateLimiter, :password_reset when action == :password_reset)

  @local_mastodon_name "Mastodon-Local"

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  def create_app(conn, params) do
    scopes = Scopes.fetch_scopes(params, ["read"])

    app_attrs =
      params
      |> Map.drop(["scope", "scopes"])
      |> Map.put("scopes", scopes)

    with cs <- App.register_changeset(%App{}, app_attrs),
         false <- cs.changes[:client_name] == @local_mastodon_name,
         {:ok, app} <- Repo.insert(cs) do
      conn
      |> put_view(AppView)
      |> render("show.json", %{app: app})
    end
  end

  def verify_app_credentials(%{assigns: %{user: _user, token: token}} = conn, _) do
    with %Token{app: %App{} = app} <- Repo.preload(token, :app) do
      conn
      |> put_view(AppView)
      |> render("short.json", %{app: app})
    end
  end

  @mastodon_api_level "2.7.2"

  def masto_instance(conn, _params) do
    instance = Config.get(:instance)

    response = %{
      uri: Web.base_url(),
      title: Keyword.get(instance, :name),
      description: Keyword.get(instance, :description),
      version: "#{@mastodon_api_level} (compatible; #{Pleroma.Application.named_version()})",
      email: Keyword.get(instance, :email),
      urls: %{
        streaming_api: Pleroma.Web.Endpoint.websocket_url()
      },
      stats: Stats.get_stats(),
      thumbnail: Web.base_url() <> "/instance/thumbnail.jpeg",
      languages: ["en"],
      registrations: Pleroma.Config.get([:instance, :registrations_open]),
      # Extra (not present in Mastodon):
      max_toot_chars: Keyword.get(instance, :limit),
      poll_limits: Keyword.get(instance, :poll_limits)
    }

    json(conn, response)
  end

  def peers(conn, _params) do
    json(conn, Stats.get_peers())
  end

  defp mastodonized_emoji do
    Pleroma.Emoji.get_all()
    |> Enum.map(fn {shortcode, %Pleroma.Emoji{file: relative_url, tags: tags}} ->
      url = to_string(URI.merge(Web.base_url(), relative_url))

      %{
        "shortcode" => shortcode,
        "static_url" => url,
        "visible_in_picker" => true,
        "url" => url,
        "tags" => tags,
        # Assuming that a comma is authorized in the category name
        "category" => (tags -- ["Custom"]) |> Enum.join(",")
      }
    end)
  end

  def custom_emojis(conn, _params) do
    mastodon_emoji = mastodonized_emoji()
    json(conn, mastodon_emoji)
  end

  def get_poll(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %Object{} = object <- Object.get_by_id_and_maybe_refetch(id, interval: 60),
         %Activity{} = activity <- Activity.get_create_by_object_ap_id(object.data["id"]),
         true <- Visibility.visible_for_user?(activity, user) do
      conn
      |> put_view(StatusView)
      |> try_render("poll.json", %{object: object, for: user})
    else
      error when is_nil(error) or error == false ->
        render_error(conn, :not_found, "Record not found")
    end
  end

  defp get_cached_vote_or_vote(user, object, choices) do
    idempotency_key = "polls:#{user.id}:#{object.data["id"]}"

    {_, res} =
      Cachex.fetch(:idempotency_cache, idempotency_key, fn _ ->
        case CommonAPI.vote(user, object, choices) do
          {:error, _message} = res -> {:ignore, res}
          res -> {:commit, res}
        end
      end)

    res
  end

  def poll_vote(%{assigns: %{user: user}} = conn, %{"id" => id, "choices" => choices}) do
    with %Object{} = object <- Object.get_by_id(id),
         true <- object.data["type"] == "Question",
         %Activity{} = activity <- Activity.get_create_by_object_ap_id(object.data["id"]),
         true <- Visibility.visible_for_user?(activity, user),
         {:ok, _activities, object} <- get_cached_vote_or_vote(user, object, choices) do
      conn
      |> put_view(StatusView)
      |> try_render("poll.json", %{object: object, for: user})
    else
      nil ->
        render_error(conn, :not_found, "Record not found")

      false ->
        render_error(conn, :not_found, "Record not found")

      {:error, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: message})
    end
  end

  def update_media(
        %{assigns: %{user: user}} = conn,
        %{"id" => id, "description" => description} = _
      )
      when is_binary(description) do
    with %Object{} = object <- Repo.get(Object, id),
         true <- Object.authorize_mutation(object, user),
         {:ok, %Object{data: data}} <- Object.update_data(object, %{"name" => description}) do
      attachment_data = Map.put(data, "id", object.id)

      conn
      |> put_view(StatusView)
      |> render("attachment.json", %{attachment: attachment_data})
    end
  end

  def update_media(_conn, _data), do: {:error, :bad_request}

  def upload(%{assigns: %{user: user}} = conn, %{"file" => file} = data) do
    with {:ok, object} <-
           ActivityPub.upload(
             file,
             actor: User.ap_id(user),
             description: Map.get(data, "description")
           ) do
      attachment_data = Map.put(object.data, "id", object.id)

      conn
      |> put_view(StatusView)
      |> render("attachment.json", %{attachment: attachment_data})
    end
  end

  def follows(%{assigns: %{user: follower}} = conn, %{"uri" => uri}) do
    with {_, %User{} = followed} <- {:followed, User.get_cached_by_nickname(uri)},
         {_, true} <- {:followed, follower.id != followed.id},
         {:ok, follower, followed, _} <- CommonAPI.follow(follower, followed) do
      conn
      |> put_view(AccountView)
      |> render("show.json", %{user: followed, for: follower})
    else
      {:followed, _} ->
        {:error, :not_found}

      {:error, message} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: message})
    end
  end

  def mutes(%{assigns: %{user: user}} = conn, _) do
    with muted_accounts <- User.muted_users(user) do
      res = AccountView.render("index.json", users: muted_accounts, for: user, as: :user)
      json(conn, res)
    end
  end

  def blocks(%{assigns: %{user: user}} = conn, _) do
    with blocked_accounts <- User.blocked_users(user) do
      res = AccountView.render("index.json", users: blocked_accounts, for: user, as: :user)
      json(conn, res)
    end
  end

  def favourites(%{assigns: %{user: user}} = conn, params) do
    params =
      params
      |> Map.put("type", "Create")
      |> Map.put("favorited_by", user.ap_id)
      |> Map.put("blocking_user", user)

    activities =
      ActivityPub.fetch_activities([], params)
      |> Enum.reverse()

    conn
    |> add_link_headers(activities)
    |> put_view(StatusView)
    |> render("index.json", %{activities: activities, for: user, as: :activity})
  end

  def bookmarks(%{assigns: %{user: user}} = conn, params) do
    user = User.get_cached_by_id(user.id)

    bookmarks =
      Bookmark.for_user_query(user.id)
      |> Pagination.fetch_paginated(params)

    activities =
      bookmarks
      |> Enum.map(fn b -> Map.put(b.activity, :bookmark, Map.delete(b, :activity)) end)

    conn
    |> add_link_headers(bookmarks)
    |> put_view(StatusView)
    |> render("index.json", %{activities: activities, for: user, as: :activity})
  end

  def index(%{assigns: %{user: user}} = conn, _params) do
    token = get_session(conn, :oauth_token)

    if user && token do
      mastodon_emoji = mastodonized_emoji()

      limit = Config.get([:instance, :limit])

      accounts = Map.put(%{}, user.id, AccountView.render("show.json", %{user: user, for: user}))

      initial_state =
        %{
          meta: %{
            streaming_api_base_url: Pleroma.Web.Endpoint.websocket_url(),
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
            max_toot_chars: limit,
            mascot: User.get_mascot(user)["url"]
          },
          poll_limits: Config.get([:instance, :poll_limits]),
          rights: %{
            delete_others_notice: present?(user.info.is_moderator),
            admin: present?(user.info.is_admin)
          },
          compose: %{
            me: "#{user.id}",
            default_privacy: user.info.default_scope,
            default_sensitive: false,
            allow_content_types: Config.get([:instance, :allowed_post_formats])
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
            user.info.settings ||
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
      |> put_view(MastodonView)
      |> render("index.html", %{initial_state: initial_state})
    else
      conn
      |> put_session(:return_to, conn.request_path)
      |> redirect(to: "/web/login")
    end
  end

  def put_settings(%{assigns: %{user: user}} = conn, %{"data" => settings} = _params) do
    with {:ok, _} <- User.update_info(user, &User.Info.mastodon_settings_update(&1, settings)) do
      json(conn, %{})
    else
      e ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: inspect(e)})
    end
  end

  def login(%{assigns: %{user: %User{}}} = conn, _params) do
    redirect(conn, to: local_mastodon_root_path(conn))
  end

  @doc "Local Mastodon FE login init action"
  def login(conn, %{"code" => auth_token}) do
    with {:ok, app} <- get_or_make_app(),
         {:ok, auth} <- Authorization.get_by_token(app, auth_token),
         {:ok, token} <- Token.exchange_token(app, auth) do
      conn
      |> put_session(:oauth_token, token.token)
      |> redirect(to: local_mastodon_root_path(conn))
    end
  end

  @doc "Local Mastodon FE callback action"
  def login(conn, _) do
    with {:ok, app} <- get_or_make_app() do
      path =
        o_auth_path(conn, :authorize,
          response_type: "code",
          client_id: app.client_id,
          redirect_uri: ".",
          scope: Enum.join(app.scopes, " ")
        )

      redirect(conn, to: path)
    end
  end

  defp local_mastodon_root_path(conn) do
    case get_session(conn, :return_to) do
      nil ->
        mastodon_api_path(conn, :index, ["getting-started"])

      return_to ->
        delete_session(conn, :return_to)
        return_to
    end
  end

  @spec get_or_make_app() :: {:ok, App.t()} | {:error, Ecto.Changeset.t()}
  defp get_or_make_app do
    App.get_or_make(
      %{client_name: @local_mastodon_name, redirect_uris: "."},
      ["read", "write", "follow", "push"]
    )
  end

  def logout(conn, _) do
    conn
    |> clear_session
    |> redirect(to: "/")
  end

  # Stubs for unimplemented mastodon api
  #
  def empty_array(conn, _) do
    Logger.debug("Unimplemented, returning an empty array")
    json(conn, [])
  end

  def empty_object(conn, _) do
    Logger.debug("Unimplemented, returning an empty object")
    json(conn, %{})
  end

  def suggestions(%{assigns: %{user: user}} = conn, _) do
    suggestions = Config.get(:suggestions)

    if Keyword.get(suggestions, :enabled, false) do
      api = Keyword.get(suggestions, :third_party_engine, "")
      timeout = Keyword.get(suggestions, :timeout, 5000)
      limit = Keyword.get(suggestions, :limit, 23)

      host = Config.get([Pleroma.Web.Endpoint, :url, :host])

      user = user.nickname

      url =
        api
        |> String.replace("{{host}}", host)
        |> String.replace("{{user}}", user)

      with {:ok, %{status: 200, body: body}} <-
             HTTP.get(url, [], adapter: [recv_timeout: timeout, pool: :default]),
           {:ok, data} <- Jason.decode(body) do
        data =
          data
          |> Enum.slice(0, limit)
          |> Enum.map(fn x ->
            x
            |> Map.put("id", fetch_suggestion_id(x))
            |> Map.put("avatar", MediaProxy.url(x["avatar"]))
            |> Map.put("avatar_static", MediaProxy.url(x["avatar_static"]))
          end)

        json(conn, data)
      else
        e ->
          Logger.error("Could not retrieve suggestions at fetch #{url}, #{inspect(e)}")
      end
    else
      json(conn, [])
    end
  end

  defp fetch_suggestion_id(attrs) do
    case User.get_or_fetch(attrs["acct"]) do
      {:ok, %User{id: id}} -> id
      _ -> 0
    end
  end

  def password_reset(conn, params) do
    nickname_or_email = params["email"] || params["nickname"]

    with {:ok, _} <- TwitterAPI.password_reset(nickname_or_email) do
      conn
      |> put_status(:no_content)
      |> json("")
    else
      {:error, "unknown user"} ->
        send_resp(conn, :not_found, "")

      {:error, _} ->
        send_resp(conn, :bad_request, "")
    end
  end

  def try_render(conn, target, params)
      when is_binary(target) do
    case render(conn, target, params) do
      nil -> render_error(conn, :not_implemented, "Can't display this activity")
      res -> res
    end
  end

  def try_render(conn, _, _) do
    render_error(conn, :not_implemented, "Can't display this activity")
  end

  defp present?(nil), do: false
  defp present?(false), do: false
  defp present?(_), do: true
end
