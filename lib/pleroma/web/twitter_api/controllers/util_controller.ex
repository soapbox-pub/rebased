# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.UtilController do
  use Pleroma.Web, :controller

  require Logger

  alias Pleroma.Activity
  alias Pleroma.Config
  alias Pleroma.Emoji
  alias Pleroma.Healthcheck
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Pleroma.Web.WebFinger

  plug(
    Pleroma.Web.ApiSpec.CastAndValidate
    when action != :remote_subscribe and action != :show_subscribe_form
  )

  plug(
    Pleroma.Web.Plugs.FederatingPlug
    when action == :remote_subscribe
    when action == :show_subscribe_form
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:accounts"]}
    when action in [
           :change_email,
           :change_password,
           :delete_account,
           :update_notificaton_settings,
           :disable_account,
           :move_account,
           :add_alias,
           :delete_alias
         ]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:accounts"]}
    when action in [
           :list_aliases
         ]
  )

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.TwitterUtilOperation

  def show_subscribe_form(conn, %{"nickname" => nick}) do
    with %User{} = user <- User.get_cached_by_nickname(nick),
         avatar = User.avatar_url(user) do
      conn
      |> render("subscribe.html", %{nickname: nick, avatar: avatar, error: false})
    else
      _e ->
        render(conn, "subscribe.html", %{
          nickname: nick,
          avatar: nil,
          error:
            Pleroma.Web.Gettext.dpgettext(
              "static_pages",
              "remote follow error message - user not found",
              "Could not find user"
            )
        })
    end
  end

  def show_subscribe_form(conn, %{"status_id" => id}) do
    with %Activity{} = activity <- Activity.get_by_id(id),
         {:ok, ap_id} <- get_ap_id(activity),
         %User{} = user <- User.get_cached_by_ap_id(activity.actor),
         avatar = User.avatar_url(user) do
      conn
      |> render("status_interact.html", %{
        status_link: ap_id,
        status_id: id,
        nickname: user.nickname,
        avatar: avatar,
        error: false
      })
    else
      _e ->
        render(conn, "status_interact.html", %{
          status_id: id,
          avatar: nil,
          error:
            Pleroma.Web.Gettext.dpgettext(
              "static_pages",
              "status interact error message - status not found",
              "Could not find status"
            )
        })
    end
  end

  def remote_subscribe(conn, %{"nickname" => nick, "profile" => _}) do
    show_subscribe_form(conn, %{"nickname" => nick})
  end

  def remote_subscribe(conn, %{"status_id" => id, "profile" => _}) do
    show_subscribe_form(conn, %{"status_id" => id})
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
          error:
            Pleroma.Web.Gettext.dpgettext(
              "static_pages",
              "remote follow error message - unknown error",
              "Something went wrong."
            )
        })
    end
  end

  def remote_subscribe(conn, %{"status" => %{"status_id" => id, "profile" => profile}}) do
    with {:ok, %{"subscribe_address" => template}} <- WebFinger.finger(profile),
         %Activity{} = activity <- Activity.get_by_id(id),
         {:ok, ap_id} <- get_ap_id(activity) do
      conn
      |> Phoenix.Controller.redirect(external: String.replace(template, "{uri}", ap_id))
    else
      _e ->
        render(conn, "status_interact.html", %{
          status_id: id,
          avatar: nil,
          error:
            Pleroma.Web.Gettext.dpgettext(
              "static_pages",
              "status interact error message - unknown error",
              "Something went wrong."
            )
        })
    end
  end

  def remote_interaction(%{body_params: %{ap_id: ap_id, profile: profile}} = conn, _params) do
    with {:ok, %{"subscribe_address" => template}} <- WebFinger.finger(profile) do
      conn
      |> json(%{url: String.replace(template, "{uri}", ap_id)})
    else
      _e -> json(conn, %{error: "Couldn't find user"})
    end
  end

  defp get_ap_id(activity) do
    object = Pleroma.Object.normalize(activity, fetch: false)

    case object do
      %{data: %{"id" => ap_id}} -> {:ok, ap_id}
      _ -> {:no_ap_id, nil}
    end
  end

  def frontend_configurations(conn, _params) do
    render(conn, "frontend_configurations.json")
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

  def change_password(%{assigns: %{user: user}, body_params: body_params} = conn, %{}) do
    case CommonAPI.Utils.confirm_current_password(user, body_params.password) do
      {:ok, user} ->
        with {:ok, _user} <-
               User.reset_password(user, %{
                 password: body_params.new_password,
                 password_confirmation: body_params.new_password_confirmation
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

  def change_email(%{assigns: %{user: user}, body_params: body_params} = conn, %{}) do
    case CommonAPI.Utils.confirm_current_password(user, body_params.password) do
      {:ok, user} ->
        with {:ok, _user} <- User.change_email(user, body_params.email) do
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

  def delete_account(%{assigns: %{user: user}, body_params: body_params} = conn, params) do
    # This endpoint can accept a query param or JSON body for backwards-compatibility.
    # Submitting a JSON body is recommended, so passwords don't end up in server logs.
    password = body_params[:password] || params[:password] || ""

    case CommonAPI.Utils.confirm_current_password(user, password) do
      {:ok, user} ->
        User.delete(user)
        json(conn, %{status: "success"})

      {:error, msg} ->
        json(conn, %{error: msg})
    end
  end

  def disable_account(%{assigns: %{user: user}} = conn, params) do
    case CommonAPI.Utils.confirm_current_password(user, params[:password]) do
      {:ok, user} ->
        User.set_activation_async(user, false)
        json(conn, %{status: "success"})

      {:error, msg} ->
        json(conn, %{error: msg})
    end
  end

  def move_account(%{assigns: %{user: user}, body_params: body_params} = conn, %{}) do
    case CommonAPI.Utils.confirm_current_password(user, body_params.password) do
      {:ok, user} ->
        with {:ok, target_user} <- find_or_fetch_user_by_nickname(body_params.target_account),
             {:ok, _user} <- ActivityPub.move(user, target_user) do
          json(conn, %{status: "success"})
        else
          {:not_found, _} ->
            conn
            |> put_status(404)
            |> json(%{error: "Target account not found."})

          {:error, error} ->
            json(conn, %{error: error})
        end

      {:error, msg} ->
        json(conn, %{error: msg})
    end
  end

  def add_alias(%{assigns: %{user: user}, body_params: body_params} = conn, _) do
    with {:ok, alias_user} <- find_user_by_nickname(body_params.alias),
         {:ok, _user} <- user |> User.add_alias(alias_user) do
      json(conn, %{status: "success"})
    else
      {:not_found, _} ->
        conn
        |> put_status(404)
        |> json(%{error: "Target account does not exist."})

      {:error, error} ->
        json(conn, %{error: error})
    end
  end

  def delete_alias(%{assigns: %{user: user}, body_params: body_params} = conn, _) do
    with {:ok, alias_user} <- find_user_by_nickname(body_params.alias),
         {:ok, _user} <- user |> User.delete_alias(alias_user) do
      json(conn, %{status: "success"})
    else
      {:error, :no_such_alias} ->
        conn
        |> put_status(404)
        |> json(%{error: "Account has no such alias."})

      {:error, error} ->
        json(conn, %{error: error})
    end
  end

  def list_aliases(%{assigns: %{user: user}} = conn, %{}) do
    alias_nicks =
      user
      |> User.alias_users()
      |> Enum.map(&User.full_nickname/1)

    json(conn, %{aliases: alias_nicks})
  end

  defp find_user_by_nickname(nickname) do
    user = User.get_cached_by_nickname(nickname)

    if user == nil do
      {:not_found, nil}
    else
      {:ok, user}
    end
  end

  defp find_or_fetch_user_by_nickname(nickname) do
    user = User.get_by_nickname(nickname)

    if user != nil and user.local do
      {:ok, user}
    else
      with {:ok, user} <- User.fetch_by_nickname(nickname) do
        {:ok, user}
      else
        _ ->
          {:not_found, nil}
      end
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
