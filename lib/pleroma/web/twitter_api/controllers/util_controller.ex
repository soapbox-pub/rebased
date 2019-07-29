# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.UtilController do
  use Pleroma.Web, :controller

  require Logger

  alias Pleroma.Activity
  alias Pleroma.Config
  alias Pleroma.Emoji
  alias Pleroma.Healthcheck
  alias Pleroma.Notification
  alias Pleroma.Plugs.AuthenticationPlug
  alias Pleroma.User
  alias Pleroma.Web
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.WebFinger

  def help_test(conn, _params) do
    json(conn, "ok")
  end

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

  def remote_follow(%{assigns: %{user: user}} = conn, %{"acct" => acct}) do
    if is_status?(acct) do
      {:ok, object} = Pleroma.Object.Fetcher.fetch_object_from_id(acct)
      %Activity{id: activity_id} = Activity.get_create_by_object_ap_id(object.data["id"])
      redirect(conn, to: "/notice/#{activity_id}")
    else
      {err, followee} = User.get_or_fetch(acct)
      avatar = User.avatar_url(followee)
      name = followee.nickname
      id = followee.id

      if !!user do
        conn
        |> render("follow.html", %{error: err, acct: acct, avatar: avatar, name: name, id: id})
      else
        conn
        |> render("follow_login.html", %{
          error: false,
          acct: acct,
          avatar: avatar,
          name: name,
          id: id
        })
      end
    end
  end

  defp is_status?(acct) do
    case Pleroma.Object.Fetcher.fetch_and_contain_remote_object_from_id(acct) do
      {:ok, %{"type" => type}} when type in ["Article", "Note", "Video", "Page", "Question"] ->
        true

      _ ->
        false
    end
  end

  def do_remote_follow(conn, %{
        "authorization" => %{"name" => username, "password" => password, "id" => id}
      }) do
    followee = User.get_cached_by_id(id)
    avatar = User.avatar_url(followee)
    name = followee.nickname

    with %User{} = user <- User.get_cached_by_nickname(username),
         true <- AuthenticationPlug.checkpw(password, user.password_hash),
         %User{} = _followed <- User.get_cached_by_id(id),
         {:ok, _follower, _followee, _activity} <- CommonAPI.follow(user, followee) do
      conn
      |> render("followed.html", %{error: false})
    else
      # Was already following user
      {:error, "Could not follow user:" <> _rest} ->
        render(conn, "followed.html", %{error: false})

      _e ->
        conn
        |> render("follow_login.html", %{
          error: "Wrong username or password",
          id: id,
          name: name,
          avatar: avatar
        })
    end
  end

  def do_remote_follow(%{assigns: %{user: user}} = conn, %{"user" => %{"id" => id}}) do
    with %User{} = followee <- User.get_cached_by_id(id),
         {:ok, _follower, _followee, _activity} <- CommonAPI.follow(user, followee) do
      conn
      |> render("followed.html", %{error: false})
    else
      # Was already following user
      {:error, "Could not follow user:" <> _rest} ->
        conn
        |> render("followed.html", %{error: false})

      e ->
        Logger.debug("Remote follow failed with error #{inspect(e)}")

        conn
        |> render("followed.html", %{error: inspect(e)})
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

  def config(conn, _params) do
    instance = Pleroma.Config.get(:instance)

    case get_format(conn) do
      "xml" ->
        response = """
        <config>
          <site>
            <name>#{Keyword.get(instance, :name)}</name>
            <site>#{Web.base_url()}</site>
            <textlimit>#{Keyword.get(instance, :limit)}</textlimit>
            <closed>#{!Keyword.get(instance, :registrations_open)}</closed>
          </site>
        </config>
        """

        conn
        |> put_resp_content_type("application/xml")
        |> send_resp(200, response)

      _ ->
        vapid_public_key = Keyword.get(Pleroma.Web.Push.vapid_config(), :public_key)

        uploadlimit = %{
          uploadlimit: to_string(Keyword.get(instance, :upload_limit)),
          avatarlimit: to_string(Keyword.get(instance, :avatar_upload_limit)),
          backgroundlimit: to_string(Keyword.get(instance, :background_upload_limit)),
          bannerlimit: to_string(Keyword.get(instance, :banner_upload_limit))
        }

        data = %{
          name: Keyword.get(instance, :name),
          description: Keyword.get(instance, :description),
          server: Web.base_url(),
          textlimit: to_string(Keyword.get(instance, :limit)),
          uploadlimit: uploadlimit,
          closed: if(Keyword.get(instance, :registrations_open), do: "0", else: "1"),
          private: if(Keyword.get(instance, :public, true), do: "0", else: "1"),
          vapidPublicKey: vapid_public_key,
          accountActivationRequired:
            if(Keyword.get(instance, :account_activation_required, false), do: "1", else: "0"),
          invitesEnabled: if(Keyword.get(instance, :invites_enabled, false), do: "1", else: "0"),
          safeDMMentionsEnabled:
            if(Pleroma.Config.get([:instance, :safe_dm_mentions]), do: "1", else: "0")
        }

        pleroma_fe = Pleroma.Config.get([:frontend_configurations, :pleroma_fe])

        managed_config = Keyword.get(instance, :managed_config)

        data =
          if managed_config do
            data |> Map.put("pleromafe", pleroma_fe)
          else
            data
          end

        json(conn, %{site: data})
    end
  end

  def frontend_configurations(conn, _params) do
    config =
      Pleroma.Config.get(:frontend_configurations, %{})
      |> Enum.into(%{})

    json(conn, config)
  end

  def version(conn, _params) do
    version = Pleroma.Application.named_version()

    case get_format(conn) do
      "xml" ->
        response = "<version>#{version}</version>"

        conn
        |> put_resp_content_type("application/xml")
        |> send_resp(200, response)

      _ ->
        json(conn, version)
    end
  end

  def emoji(conn, _params) do
    emoji =
      Emoji.get_all()
      |> Enum.map(fn {short_code, path, tags} ->
        {short_code, %{image_url: path, tags: tags}}
      end)
      |> Enum.into(%{})

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
      PleromaJobQueue.enqueue(:background, User, [
        :follow_import,
        follower,
        followed_identifiers
      ])

      json(conn, "job started")
    end
  end

  def blocks_import(conn, %{"list" => %Plug.Upload{} = listfile}) do
    blocks_import(conn, %{"list" => File.read!(listfile.path)})
  end

  def blocks_import(%{assigns: %{user: blocker}} = conn, %{"list" => list}) do
    with blocked_identifiers <- String.split(list) do
      PleromaJobQueue.enqueue(:background, User, [
        :blocks_import,
        blocker,
        blocked_identifiers
      ])

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

  def delete_account(%{assigns: %{user: user}} = conn, params) do
    case CommonAPI.Utils.confirm_current_password(user, params["password"]) do
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
