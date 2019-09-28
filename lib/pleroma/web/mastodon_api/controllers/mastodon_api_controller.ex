# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MastodonAPIController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper,
    only: [json_response: 3, add_link_headers: 2, truthy_param?: 1]

  alias Ecto.Changeset
  alias Pleroma.Activity
  alias Pleroma.Bookmark
  alias Pleroma.Config
  alias Pleroma.Conversation.Participation
  alias Pleroma.Emoji
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
  alias Pleroma.Web.MastodonAPI.ConversationView
  alias Pleroma.Web.MastodonAPI.ListView
  alias Pleroma.Web.MastodonAPI.MastodonAPI
  alias Pleroma.Web.MastodonAPI.MastodonView
  alias Pleroma.Web.MastodonAPI.ReportView
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.MediaProxy
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Authorization
  alias Pleroma.Web.OAuth.Scopes
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.TwitterAPI.TwitterAPI

  require Logger
  require Pleroma.Constants

  @rate_limited_relations_actions ~w(follow unfollow)a

  plug(
    RateLimiter,
    {:relations_id_action, params: ["id", "uri"]} when action in @rate_limited_relations_actions
  )

  plug(RateLimiter, :relations_actions when action in @rate_limited_relations_actions)
  plug(RateLimiter, :app_account_creation when action == :account_register)
  plug(RateLimiter, :search when action in [:search, :search2, :account_search])
  plug(RateLimiter, :password_reset when action == :password_reset)
  plug(RateLimiter, :account_confirmation_resend when action == :account_confirmation_resend)

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
      |> add_if_present(params, "note", :bio, fn value -> {:ok, User.parse_bio(value, user)} end)
      |> add_if_present(params, "avatar", :avatar, fn value ->
        with %Plug.Upload{} <- value,
             {:ok, object} <- ActivityPub.upload(value, type: :avatar) do
          {:ok, object.data}
        else
          _ -> :error
        end
      end)

    emojis_text = (user_params["display_name"] || "") <> (user_params["note"] || "")

    user_info_emojis =
      user.info
      |> Map.get(:emoji, [])
      |> Enum.concat(Emoji.Formatter.get_emoji_map(emojis_text))
      |> Enum.dedup()

    info_params =
      [
        :no_rich_text,
        :locked,
        :hide_followers_count,
        :hide_follows_count,
        :hide_followers,
        :hide_follows,
        :hide_favorites,
        :show_role,
        :skip_thread_containment,
        :discoverable
      ]
      |> Enum.reduce(%{}, fn key, acc ->
        add_if_present(acc, params, to_string(key), key, fn value ->
          {:ok, truthy_param?(value)}
        end)
      end)
      |> add_if_present(params, "default_scope", :default_scope)
      |> add_if_present(params, "fields", :fields, fn fields ->
        fields = Enum.map(fields, fn f -> Map.update!(f, "value", &AutoLinker.link(&1)) end)

        {:ok, fields}
      end)
      |> add_if_present(params, "fields", :raw_fields)
      |> add_if_present(params, "pleroma_settings_store", :pleroma_settings_store, fn value ->
        {:ok, Map.merge(user.info.pleroma_settings_store, value)}
      end)
      |> add_if_present(params, "header", :banner, fn value ->
        with %Plug.Upload{} <- value,
             {:ok, object} <- ActivityPub.upload(value, type: :banner) do
          {:ok, object.data}
        else
          _ -> :error
        end
      end)
      |> add_if_present(params, "pleroma_background_image", :background, fn value ->
        with %Plug.Upload{} <- value,
             {:ok, object} <- ActivityPub.upload(value, type: :background) do
          {:ok, object.data}
        else
          _ -> :error
        end
      end)
      |> Map.put(:emoji, user_info_emojis)

    changeset =
      user
      |> User.update_changeset(user_params)
      |> User.change_info(&User.Info.profile_update(&1, info_params))

    with {:ok, user} <- User.update_and_set_cache(changeset) do
      if original_user != user, do: CommonAPI.update(user)

      json(
        conn,
        AccountView.render("account.json", %{user: user, for: user, with_pleroma_settings: true})
      )
    else
      _e -> render_error(conn, :forbidden, "Invalid request")
    end
  end

  def update_avatar(%{assigns: %{user: user}} = conn, %{"img" => ""}) do
    change = Changeset.change(user, %{avatar: nil})
    {:ok, user} = User.update_and_set_cache(change)
    CommonAPI.update(user)

    json(conn, %{url: nil})
  end

  def update_avatar(%{assigns: %{user: user}} = conn, params) do
    {:ok, object} = ActivityPub.upload(params, type: :avatar)
    change = Changeset.change(user, %{avatar: object.data})
    {:ok, user} = User.update_and_set_cache(change)
    CommonAPI.update(user)
    %{"url" => [%{"href" => href} | _]} = object.data

    json(conn, %{url: href})
  end

  def update_banner(%{assigns: %{user: user}} = conn, %{"banner" => ""}) do
    new_info = %{"banner" => %{}}

    with {:ok, user} <- User.update_info(user, &User.Info.profile_update(&1, new_info)) do
      CommonAPI.update(user)
      json(conn, %{url: nil})
    end
  end

  def update_banner(%{assigns: %{user: user}} = conn, params) do
    with {:ok, object} <- ActivityPub.upload(%{"img" => params["banner"]}, type: :banner),
         new_info <- %{"banner" => object.data},
         {:ok, user} <- User.update_info(user, &User.Info.profile_update(&1, new_info)) do
      CommonAPI.update(user)
      %{"url" => [%{"href" => href} | _]} = object.data

      json(conn, %{url: href})
    end
  end

  def update_background(%{assigns: %{user: user}} = conn, %{"img" => ""}) do
    new_info = %{"background" => %{}}

    with {:ok, _user} <- User.update_info(user, &User.Info.profile_update(&1, new_info)) do
      json(conn, %{url: nil})
    end
  end

  def update_background(%{assigns: %{user: user}} = conn, params) do
    with {:ok, object} <- ActivityPub.upload(params, type: :background),
         new_info <- %{"background" => object.data},
         {:ok, _user} <- User.update_info(user, &User.Info.profile_update(&1, new_info)) do
      %{"url" => [%{"href" => href} | _]} = object.data

      json(conn, %{url: href})
    end
  end

  def verify_credentials(%{assigns: %{user: user}} = conn, _) do
    chat_token = Phoenix.Token.sign(conn, "user socket", user.id)

    account =
      AccountView.render("account.json", %{
        user: user,
        for: user,
        with_pleroma_settings: true,
        with_chat_token: chat_token
      })

    json(conn, account)
  end

  def verify_app_credentials(%{assigns: %{user: _user, token: token}} = conn, _) do
    with %Token{app: %App{} = app} <- Repo.preload(token, :app) do
      conn
      |> put_view(AppView)
      |> render("short.json", %{app: app})
    end
  end

  def user(%{assigns: %{user: for_user}} = conn, %{"id" => nickname_or_id}) do
    with %User{} = user <- User.get_cached_by_nickname_or_id(nickname_or_id, for: for_user),
         true <- User.auth_active?(user) || user.id == for_user.id || User.superuser?(for_user) do
      account = AccountView.render("account.json", %{user: user, for: for_user})
      json(conn, account)
    else
      _e -> render_error(conn, :not_found, "Can't find user")
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

  def user_statuses(%{assigns: %{user: reading_user}} = conn, params) do
    with %User{} = user <- User.get_cached_by_nickname_or_id(params["id"], for: reading_user) do
      params =
        params
        |> Map.put("tag", params["tagged"])

      activities = ActivityPub.fetch_user_activities(user, reading_user, params)

      conn
      |> add_link_headers(activities)
      |> put_view(StatusView)
      |> render("index.json", %{
        activities: activities,
        for: reading_user,
        as: :activity
      })
    end
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

  def relationships(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    targets = User.get_all_by_ids(List.wrap(id))

    conn
    |> put_view(AccountView)
    |> render("relationships.json", %{user: user, targets: targets})
  end

  # Instead of returning a 400 when no "id" params is present, Mastodon returns an empty array.
  def relationships(%{assigns: %{user: _user}} = conn, _), do: json(conn, [])

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

  def set_mascot(%{assigns: %{user: user}} = conn, %{"file" => file}) do
    with {:ok, object} <- ActivityPub.upload(file, actor: User.ap_id(user)),
         %{} = attachment_data <- Map.put(object.data, "id", object.id),
         # Reject if not an image
         %{type: "image"} = rendered <-
           StatusView.render("attachment.json", %{attachment: attachment_data}) do
      # Sure!
      # Save to the user's info
      {:ok, _user} = User.update_info(user, &User.Info.mascot_update(&1, rendered))

      json(conn, rendered)
    else
      %{type: _} -> render_error(conn, :unsupported_media_type, "mascots can only be images")
    end
  end

  def get_mascot(%{assigns: %{user: user}} = conn, _params) do
    mascot = User.get_mascot(user)

    json(conn, mascot)
  end

  def followers(%{assigns: %{user: for_user}} = conn, %{"id" => id} = params) do
    with %User{} = user <- User.get_cached_by_id(id),
         followers <- MastodonAPI.get_followers(user, params) do
      followers =
        cond do
          for_user && user.id == for_user.id -> followers
          user.info.hide_followers -> []
          true -> followers
        end

      conn
      |> add_link_headers(followers)
      |> put_view(AccountView)
      |> render("accounts.json", %{for: for_user, users: followers, as: :user})
    end
  end

  def following(%{assigns: %{user: for_user}} = conn, %{"id" => id} = params) do
    with %User{} = user <- User.get_cached_by_id(id),
         followers <- MastodonAPI.get_friends(user, params) do
      followers =
        cond do
          for_user && user.id == for_user.id -> followers
          user.info.hide_follows -> []
          true -> followers
        end

      conn
      |> add_link_headers(followers)
      |> put_view(AccountView)
      |> render("accounts.json", %{for: for_user, users: followers, as: :user})
    end
  end

  def follow(%{assigns: %{user: follower}} = conn, %{"id" => id}) do
    with {_, %User{} = followed} <- {:followed, User.get_cached_by_id(id)},
         {_, true} <- {:followed, follower.id != followed.id},
         {:ok, follower} <- MastodonAPI.follow(follower, followed, conn.params) do
      conn
      |> put_view(AccountView)
      |> render("relationship.json", %{user: follower, target: followed})
    else
      {:followed, _} ->
        {:error, :not_found}

      {:error, message} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: message})
    end
  end

  def follow(%{assigns: %{user: follower}} = conn, %{"uri" => uri}) do
    with {_, %User{} = followed} <- {:followed, User.get_cached_by_nickname(uri)},
         {_, true} <- {:followed, follower.id != followed.id},
         {:ok, follower, followed, _} <- CommonAPI.follow(follower, followed) do
      conn
      |> put_view(AccountView)
      |> render("account.json", %{user: followed, for: follower})
    else
      {:followed, _} ->
        {:error, :not_found}

      {:error, message} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: message})
    end
  end

  def unfollow(%{assigns: %{user: follower}} = conn, %{"id" => id}) do
    with {_, %User{} = followed} <- {:followed, User.get_cached_by_id(id)},
         {_, true} <- {:followed, follower.id != followed.id},
         {:ok, follower} <- CommonAPI.unfollow(follower, followed) do
      conn
      |> put_view(AccountView)
      |> render("relationship.json", %{user: follower, target: followed})
    else
      {:followed, _} ->
        {:error, :not_found}

      error ->
        error
    end
  end

  def mute(%{assigns: %{user: muter}} = conn, %{"id" => id} = params) do
    notifications =
      if Map.has_key?(params, "notifications"),
        do: params["notifications"] in [true, "True", "true", "1"],
        else: true

    with %User{} = muted <- User.get_cached_by_id(id),
         {:ok, muter} <- User.mute(muter, muted, notifications) do
      conn
      |> put_view(AccountView)
      |> render("relationship.json", %{user: muter, target: muted})
    else
      {:error, message} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: message})
    end
  end

  def unmute(%{assigns: %{user: muter}} = conn, %{"id" => id}) do
    with %User{} = muted <- User.get_cached_by_id(id),
         {:ok, muter} <- User.unmute(muter, muted) do
      conn
      |> put_view(AccountView)
      |> render("relationship.json", %{user: muter, target: muted})
    else
      {:error, message} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: message})
    end
  end

  def mutes(%{assigns: %{user: user}} = conn, _) do
    with muted_accounts <- User.muted_users(user) do
      res = AccountView.render("accounts.json", users: muted_accounts, for: user, as: :user)
      json(conn, res)
    end
  end

  def block(%{assigns: %{user: blocker}} = conn, %{"id" => id}) do
    with %User{} = blocked <- User.get_cached_by_id(id),
         {:ok, blocker} <- User.block(blocker, blocked),
         {:ok, _activity} <- ActivityPub.block(blocker, blocked) do
      conn
      |> put_view(AccountView)
      |> render("relationship.json", %{user: blocker, target: blocked})
    else
      {:error, message} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: message})
    end
  end

  def unblock(%{assigns: %{user: blocker}} = conn, %{"id" => id}) do
    with %User{} = blocked <- User.get_cached_by_id(id),
         {:ok, blocker} <- User.unblock(blocker, blocked),
         {:ok, _activity} <- ActivityPub.unblock(blocker, blocked) do
      conn
      |> put_view(AccountView)
      |> render("relationship.json", %{user: blocker, target: blocked})
    else
      {:error, message} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: message})
    end
  end

  def blocks(%{assigns: %{user: user}} = conn, _) do
    with blocked_accounts <- User.blocked_users(user) do
      res = AccountView.render("accounts.json", users: blocked_accounts, for: user, as: :user)
      json(conn, res)
    end
  end

  def subscribe(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %User{} = subscription_target <- User.get_cached_by_id(id),
         {:ok, subscription_target} = User.subscribe(user, subscription_target) do
      conn
      |> put_view(AccountView)
      |> render("relationship.json", %{user: user, target: subscription_target})
    else
      nil -> {:error, :not_found}
      e -> e
    end
  end

  def unsubscribe(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %User{} = subscription_target <- User.get_cached_by_id(id),
         {:ok, subscription_target} = User.unsubscribe(user, subscription_target) do
      conn
      |> put_view(AccountView)
      |> render("relationship.json", %{user: user, target: subscription_target})
    else
      nil -> {:error, :not_found}
      e -> e
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

  def user_favourites(%{assigns: %{user: for_user}} = conn, %{"id" => id} = params) do
    with %User{} = user <- User.get_by_id(id),
         false <- user.info.hide_favorites do
      params =
        params
        |> Map.put("type", "Create")
        |> Map.put("favorited_by", user.ap_id)
        |> Map.put("blocking_user", for_user)

      recipients =
        if for_user do
          [Pleroma.Constants.as_public()] ++ [for_user.ap_id | for_user.following]
        else
          [Pleroma.Constants.as_public()]
        end

      activities =
        recipients
        |> ActivityPub.fetch_activities(params)
        |> Enum.reverse()

      conn
      |> add_link_headers(activities)
      |> put_view(StatusView)
      |> render("index.json", %{activities: activities, for: for_user, as: :activity})
    else
      nil -> {:error, :not_found}
      true -> render_error(conn, :forbidden, "Can't get favorites")
    end
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

  def account_lists(%{assigns: %{user: user}} = conn, %{"id" => account_id}) do
    lists = Pleroma.List.get_lists_account_belongs(user, account_id)

    conn
    |> put_view(ListView)
    |> render("index.json", %{lists: lists})
  end

  def index(%{assigns: %{user: user}} = conn, _params) do
    token = get_session(conn, :oauth_token)

    if user && token do
      mastodon_emoji = mastodonized_emoji()

      limit = Config.get([:instance, :limit])

      accounts =
        Map.put(%{}, user.id, AccountView.render("account.json", %{user: user, for: user}))

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

  def reports(%{assigns: %{user: user}} = conn, params) do
    case CommonAPI.report(user, params) do
      {:ok, activity} ->
        conn
        |> put_view(ReportView)
        |> try_render("report.json", %{activity: activity})

      {:error, err} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: err})
    end
  end

  def account_register(
        %{assigns: %{app: app}} = conn,
        %{"username" => nickname, "email" => _, "password" => _, "agreement" => true} = params
      ) do
    params =
      params
      |> Map.take([
        "email",
        "captcha_solution",
        "captcha_token",
        "captcha_answer_data",
        "token",
        "password"
      ])
      |> Map.put("nickname", nickname)
      |> Map.put("fullname", params["fullname"] || nickname)
      |> Map.put("bio", params["bio"] || "")
      |> Map.put("confirm", params["password"])

    with {:ok, user} <- TwitterAPI.register_user(params, need_confirmation: true),
         {:ok, token} <- Token.create_token(app, user, %{scopes: app.scopes}) do
      json(conn, %{
        token_type: "Bearer",
        access_token: token.token,
        scope: app.scopes,
        created_at: Token.Utils.format_created_at(token)
      })
    else
      {:error, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(errors)
    end
  end

  def account_register(%{assigns: %{app: _app}} = conn, _) do
    render_error(conn, :bad_request, "Missing parameters")
  end

  def account_register(conn, _) do
    render_error(conn, :forbidden, "Invalid credentials")
  end

  def conversations(%{assigns: %{user: user}} = conn, params) do
    participations = Participation.for_user_with_last_activity_id(user, params)

    conversations =
      Enum.map(participations, fn participation ->
        ConversationView.render("participation.json", %{participation: participation, for: user})
      end)

    conn
    |> add_link_headers(participations)
    |> json(conversations)
  end

  def conversation_read(%{assigns: %{user: user}} = conn, %{"id" => participation_id}) do
    with %Participation{} = participation <-
           Repo.get_by(Participation, id: participation_id, user_id: user.id),
         {:ok, participation} <- Participation.mark_as_read(participation) do
      participation_view =
        ConversationView.render("participation.json", %{participation: participation, for: user})

      conn
      |> json(participation_view)
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

  def account_confirmation_resend(conn, params) do
    nickname_or_email = params["email"] || params["nickname"]

    with %User{} = user <- User.get_by_nickname_or_email(nickname_or_email),
         {:ok, _} <- User.try_send_confirmation_email(user) do
      conn
      |> json_response(:no_content, "")
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
