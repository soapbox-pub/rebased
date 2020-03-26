# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.UtilController do
  use Pleroma.Web, :controller

  require Logger

  alias Pleroma.Config
  alias Pleroma.Emoji
  alias Pleroma.Healthcheck
  alias Pleroma.Notification
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.WebFinger

  plug(Pleroma.Web.FederatingPlug when action == :remote_subscribe)

  plug(
    OAuthScopesPlug,
    %{scopes: ["follow", "write:follows"]}
    when action == :follow_import
  )

  # Note: follower can submit the form (with password auth) not being signed in (having no token)
  plug(
    OAuthScopesPlug,
    %{fallback: :proceed_unauthenticated, scopes: ["follow", "write:follows"]}
    when action == :do_remote_follow
  )

  plug(OAuthScopesPlug, %{scopes: ["follow", "write:blocks"]} when action == :blocks_import)

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:accounts"]}
    when action in [
           :change_email,
           :change_password,
           :delete_account,
           :update_notificaton_settings,
           :disable_account
         ]
  )

  plug(OAuthScopesPlug, %{scopes: ["write:notifications"]} when action == :notifications_read)

  def remote_subscribe(conn, %{"nickname" => nick, "profile" => _}) do
    with %User{} = user <- User.get_cached_by_nickname(nick),
         avatar = User.avatar_url(user) do
      conn
      |> render("subscribe.html", %{nickname: nick, avatar: avatar, error: false})
    else
      _e ->
        render(conn, "subscribe.html", %{
          nickname: nick,
          avatar: nil,
          error: "Could not find user"
        })
    end
  end

  def remote_subscribe(conn, %{"user" => %{"nickname" => nick, "profile" => profile}}) do
    with {:ok, %{"subscribe_address" => template}} <- WebFinger.finger(profile),
         %User{ap_id: ap_id} <- User.get_cached_by_nickname(nick) do
      conn
      |> Phoenix.Controller.redirect(external: String.replace(template, "{uri}", ap_id))
    else
      _e ->
        render(conn, "subscribe.html", %{
          nickname: nick,
          avatar: nil,
          error: "Something went wrong."
        })
    end
  end

  def notifications_read(%{assigns: %{user: user}} = conn, %{"id" => notification_id}) do
    with {:ok, _} <- Notification.read_one(user, notification_id) do
      json(conn, %{status: "success"})
    else
      {:error, message} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Jason.encode!(%{"error" => message}))
    end
  end

  # Deprecated in favor of `/nodeinfo`
  # https://git.pleroma.social/pleroma/pleroma/-/merge_requests/2327
  # https://git.pleroma.social/pleroma/pleroma-fe/-/merge_requests/1084
  def config(conn, _params) do
    json(conn, %{
      site: %{
        textlimit: to_string(Config.get([:instance, :limit])),
        vapidPublicKey: Keyword.get(Pleroma.Web.Push.vapid_config(), :public_key)
      }
    })
  end

  def frontend_configurations(conn, _params) do
    config =
      Pleroma.Config.get(:frontend_configurations, %{})
      |> Enum.into(%{})

    json(conn, config)
  end

  def emoji(conn, _params) do
    emoji =
      Enum.reduce(Emoji.get_all(), %{}, fn {code, %Emoji{file: file, tags: tags}}, acc ->
        Map.put(acc, code, %{image_url: file, tags: tags})
      end)

    json(conn, emoji)
  end

  def update_notificaton_settings(%{assigns: %{user: user}} = conn, params) do
    with {:ok, _} <- User.update_notification_settings(user, params) do
      json(conn, %{status: "success"})
    end
  end

  def follow_import(conn, %{"list" => %Plug.Upload{} = listfile}) do
    follow_import(conn, %{"list" => File.read!(listfile.path)})
  end

  def follow_import(%{assigns: %{user: follower}} = conn, %{"list" => list}) do
    with lines <- String.split(list, "\n"),
         followed_identifiers <-
           Enum.map(lines, fn line ->
             String.split(line, ",") |> List.first()
           end)
           |> List.delete("Account address") do
      User.follow_import(follower, followed_identifiers)
      json(conn, "job started")
    end
  end

  def blocks_import(conn, %{"list" => %Plug.Upload{} = listfile}) do
    blocks_import(conn, %{"list" => File.read!(listfile.path)})
  end

  def blocks_import(%{assigns: %{user: blocker}} = conn, %{"list" => list}) do
    with blocked_identifiers <- String.split(list) do
      User.blocks_import(blocker, blocked_identifiers)
      json(conn, "job started")
    end
  end

  def change_password(%{assigns: %{user: user}} = conn, params) do
    case CommonAPI.Utils.confirm_current_password(user, params["password"]) do
      {:ok, user} ->
        with {:ok, _user} <-
               User.reset_password(user, %{
                 password: params["new_password"],
                 password_confirmation: params["new_password_confirmation"]
               }) do
          json(conn, %{status: "success"})
        else
          {:error, changeset} ->
            {_, {error, _}} = Enum.at(changeset.errors, 0)
            json(conn, %{error: "New password #{error}."})

          _ ->
            json(conn, %{error: "Unable to change password."})
        end

      {:error, msg} ->
        json(conn, %{error: msg})
    end
  end

  def change_email(%{assigns: %{user: user}} = conn, params) do
    case CommonAPI.Utils.confirm_current_password(user, params["password"]) do
      {:ok, user} ->
        with {:ok, _user} <- User.change_email(user, params["email"]) do
          json(conn, %{status: "success"})
        else
          {:error, changeset} ->
            {_, {error, _}} = Enum.at(changeset.errors, 0)
            json(conn, %{error: "Email #{error}."})

          _ ->
            json(conn, %{error: "Unable to change email."})
        end

      {:error, msg} ->
        json(conn, %{error: msg})
    end
  end

  def delete_account(%{assigns: %{user: user}} = conn, params) do
    password = params["password"] || ""

    case CommonAPI.Utils.confirm_current_password(user, password) do
      {:ok, user} ->
        User.delete(user)
        json(conn, %{status: "success"})

      {:error, msg} ->
        json(conn, %{error: msg})
    end
  end

  def disable_account(%{assigns: %{user: user}} = conn, params) do
    case CommonAPI.Utils.confirm_current_password(user, params["password"]) do
      {:ok, user} ->
        User.deactivate_async(user)
        json(conn, %{status: "success"})

      {:error, msg} ->
        json(conn, %{error: msg})
    end
  end

  def captcha(conn, _params) do
    json(conn, Pleroma.Captcha.new())
  end

  def healthcheck(conn, _params) do
    with true <- Config.get([:instance, :healthcheck]),
         %{healthy: true} = info <- Healthcheck.system_info() do
      json(conn, info)
    else
      %{healthy: false} = info ->
        service_unavailable(conn, info)

      _ ->
        service_unavailable(conn, %{})
    end
  end

  defp service_unavailable(conn, info) do
    conn
    |> put_status(:service_unavailable)
    |> json(info)
  end
end
