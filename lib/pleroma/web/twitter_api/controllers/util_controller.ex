# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.UtilController do
  use Pleroma.Web, :controller

  require Logger

  alias Pleroma.Config
  alias Pleroma.Emoji
  alias Pleroma.Healthcheck
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Pleroma.Web.WebFinger

  plug(Pleroma.Web.ApiSpec.CastAndValidate when action != :remote_subscribe)
  plug(Pleroma.Web.Plugs.FederatingPlug when action == :remote_subscribe)

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
           :add_alias
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

  def remote_interaction(%{body_params: %{ap_id: ap_id, profile: profile}} = conn, _params) do
    with {:ok, %{"subscribe_address" => template}} <- WebFinger.finger(profile) do
      conn
      |> json(%{url: String.replace(template, "{uri}", ap_id)})
    else
      _e -> json(conn, %{error: "Couldn't find user"})
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
        with {:ok, target_user} <- find_user_by_nickname(body_params.target_account),
             {:ok, _user} <- ActivityPub.move(user, target_user) do
          json(conn, %{status: "success"})
        else
          {:not_found} ->
            json(conn, %{error: "Target account not found."})

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
      {:error, error} ->
        json(conn, %{error: error})
    end
  end

  def list_aliases(%{assigns: %{user: user}} = conn, %{}) do
    alias_nicks = user
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
