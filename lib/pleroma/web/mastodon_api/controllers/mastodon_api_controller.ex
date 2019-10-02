# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MastodonAPIController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [add_link_headers: 2]

  alias Pleroma.Bookmark
  alias Pleroma.Config
  alias Pleroma.Pagination
  alias Pleroma.User
  alias Pleroma.Web
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.MastodonView
  alias Pleroma.Web.MastodonAPI.StatusView

  require Logger

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

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

  defp present?(nil), do: false
  defp present?(false), do: false
  defp present?(_), do: true
end
