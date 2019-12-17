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
  alias Pleroma.Plugs.OAuthScopesPlug
  alias Pleroma.User
  alias Pleroma.Web
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.WebFinger

  plug(
    OAuthScopesPlug,
    %{scopes: ["follow", "write:follows"]}
    when action in [:do_remote_follow, :follow_import]
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

  plug(Pleroma.Plugs.SetFormatPlug when action in [:config, :version])

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
      with {:ok, followee} <- User.get_or_fetch(acct) do
        conn
        |> render(follow_template(user), %{
          error: false,
          acct: acct,
          avatar: User.avatar_url(followee),
          name: followee.nickname,
          id: followee.id
        })
      else
        {:error, _reason} ->
          render(conn, follow_template(user), %{error: :error})
      end
    end
  end

  defp follow_template(%User{} = _user), do: "follow.html"
  defp follow_template(_), do: "follow_login.html"

  defp is_status?(acct) do
    case Pleroma.Object.Fetcher.fetch_and_contain_remote_object_from_id(acct) do
      {:ok, %{"type" => type}}
      when type in ["Article", "Event", "Note", "Video", "Page", "Question"] ->
        true

      _ ->
        false
    end
  end

  def do_remote_follow(conn, %{
        "authorization" => %{"name" => username, "password" => password, "id" => id}
      }) do
    with %User{} = followee <- User.get_cached_by_id(id),
         {_, %User{} = user, _} <- {:auth, User.get_cached_by_nickname(username), followee},
         {_, true, _} <- {
           :auth,
           AuthenticationPlug.checkpw(password, user.password_hash),
           followee
         },
         {:ok, _follower, _followee, _activity} <- CommonAPI.follow(user, followee) do
      conn
      |> render("followed.html", %{error: false})
    else
      # Was already following user
      {:error, "Could not follow user:" <> _rest} ->
        render(conn, "followed.html", %{error: "Error following account"})

      {:auth, _, followee} ->
        conn
        |> render("follow_login.html", %{
          error: "Wrong username or password",
          id: id,
          name: followee.nickname,
          avatar: User.avatar_url(followee)
        })

      e ->
        Logger.debug("Remote follow failed with error #{inspect(e)}")
        render(conn, "followed.html", %{error: "Something went wrong."})
    end
  end

  def do_remote_follow(%{assigns: %{user: user}} = conn, %{"user" => %{"id" => id}}) do
    with {:fetch_user, %User{} = followee} <- {:fetch_user, User.get_cached_by_id(id)},
         {:ok, _follower, _followee, _activity} <- CommonAPI.follow(user, followee) do
      conn
      |> render("followed.html", %{error: false})
    else
      # Was already following user
      {:error, "Could not follow user:" <> _rest} ->
        render(conn, "followed.html", %{error: "Error following account"})

      {:fetch_user, error} ->
        Logger.debug("Remote follow failed with error #{inspect(error)}")
        render(conn, "followed.html", %{error: "Could not find user"})

      e ->
        Logger.debug("Remote follow failed with error #{inspect(e)}")
        render(conn, "followed.html", %{error: "Something went wrong."})
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

  def config(%{assigns: %{format: "xml"}} = conn, _params) do
    instance = Pleroma.Config.get(:instance)

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
  end

  def config(conn, _params) do
    instance = Pleroma.Config.get(:instance)

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
      closed: bool_to_val(Keyword.get(instance, :registrations_open), "0", "1"),
      private: bool_to_val(Keyword.get(instance, :public, true), "0", "1"),
      vapidPublicKey: vapid_public_key,
      accountActivationRequired:
        bool_to_val(Keyword.get(instance, :account_activation_required, false)),
      invitesEnabled: bool_to_val(Keyword.get(instance, :invites_enabled, false)),
      safeDMMentionsEnabled: bool_to_val(Pleroma.Config.get([:instance, :safe_dm_mentions]))
    }

    managed_config = Keyword.get(instance, :managed_config)

    data =
      if managed_config do
        pleroma_fe = Pleroma.Config.get([:frontend_configurations, :pleroma_fe])
        Map.put(data, "pleromafe", pleroma_fe)
      else
        data
      end

    json(conn, %{site: data})
  end

  defp bool_to_val(true), do: "1"
  defp bool_to_val(_), do: "0"
  defp bool_to_val(true, val, _), do: val
  defp bool_to_val(_, _, val), do: val

  def frontend_configurations(conn, _params) do
    config =
      Pleroma.Config.get(:frontend_configurations, %{})
      |> Enum.into(%{})

    json(conn, config)
  end

  def version(%{assigns: %{format: "xml"}} = conn, _params) do
    version = Pleroma.Application.named_version()

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, "<version>#{version}</version>")
  end

  def version(conn, _params) do
    json(conn, Pleroma.Application.named_version())
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
