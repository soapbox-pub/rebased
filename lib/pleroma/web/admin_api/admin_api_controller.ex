# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.AdminAPIController do
  use Pleroma.Web, :controller
  alias Pleroma.User
  alias Pleroma.UserInviteToken
  alias Pleroma.Web.ActivityPub.Relay
  alias Pleroma.Web.AdminAPI.AccountView
  alias Pleroma.Web.AdminAPI.Search

  import Pleroma.Web.ControllerHelper, only: [json_response: 3]

  require Logger

  @users_page_size 50

  action_fallback(:errors)

  def user_delete(conn, %{"nickname" => nickname}) do
    User.get_cached_by_nickname(nickname)
    |> User.delete()

    conn
    |> json(nickname)
  end

  def user_follow(conn, %{"follower" => follower_nick, "followed" => followed_nick}) do
    with %User{} = follower <- User.get_cached_by_nickname(follower_nick),
         %User{} = followed <- User.get_cached_by_nickname(followed_nick) do
      User.follow(follower, followed)
    end

    conn
    |> json("ok")
  end

  def user_unfollow(conn, %{"follower" => follower_nick, "followed" => followed_nick}) do
    with %User{} = follower <- User.get_cached_by_nickname(follower_nick),
         %User{} = followed <- User.get_cached_by_nickname(followed_nick) do
      User.unfollow(follower, followed)
    end

    conn
    |> json("ok")
  end

  def users_create(conn, %{"users" => users}) do
    changesets =
      Enum.map(users, fn %{"nickname" => nickname, "email" => email, "password" => password} ->
        user_data = %{
          nickname: nickname,
          name: nickname,
          email: email,
          password: password,
          password_confirmation: password,
          bio: "."
        }

        User.register_changeset(%User{}, user_data, need_confirmation: false)
      end)
      |> Enum.reduce(Ecto.Multi.new(), fn changeset, multi ->
        Ecto.Multi.insert(multi, Ecto.UUID.generate(), changeset)
      end)

    case Pleroma.Repo.transaction(changesets) do
      {:ok, users} ->
        res =
          users
          |> Map.values()
          |> Enum.map(fn user ->
            {:ok, user} = User.post_register_action(user)
            user
          end)
          |> Enum.map(&AccountView.render("created.json", %{user: &1}))

        conn
        |> json(res)

      {:error, id, changeset, _} ->
        res =
          Enum.map(changesets.operations, fn
            {current_id, {:changeset, _current_changeset, _}} when current_id == id ->
              AccountView.render("create-error.json", %{changeset: changeset})

            {_, {:changeset, current_changeset, _}} ->
              AccountView.render("create-error.json", %{changeset: current_changeset})
          end)

        conn
        |> put_status(:conflict)
        |> json(res)
    end
  end

  def user_show(conn, %{"nickname" => nickname}) do
    with %User{} = user <- User.get_cached_by_nickname(nickname) do
      conn
      |> json(AccountView.render("show.json", %{user: user}))
    else
      _ -> {:error, :not_found}
    end
  end

  def user_toggle_activation(conn, %{"nickname" => nickname}) do
    user = User.get_cached_by_nickname(nickname)

    {:ok, updated_user} = User.deactivate(user, !user.info.deactivated)

    conn
    |> json(AccountView.render("show.json", %{user: updated_user}))
  end

  def tag_users(conn, %{"nicknames" => nicknames, "tags" => tags}) do
    with {:ok, _} <- User.tag(nicknames, tags),
         do: json_response(conn, :no_content, "")
  end

  def untag_users(conn, %{"nicknames" => nicknames, "tags" => tags}) do
    with {:ok, _} <- User.untag(nicknames, tags),
         do: json_response(conn, :no_content, "")
  end

  def list_users(conn, params) do
    {page, page_size} = page_params(params)
    filters = maybe_parse_filters(params["filters"])

    search_params = %{
      query: params["query"],
      page: page,
      page_size: page_size,
      tags: params["tags"],
      name: params["name"],
      email: params["email"]
    }

    with {:ok, users, count} <- Search.user(Map.merge(search_params, filters)),
         do:
           conn
           |> json(
             AccountView.render("index.json",
               users: users,
               count: count,
               page_size: page_size
             )
           )
  end

  @filters ~w(local external active deactivated is_admin is_moderator)

  @spec maybe_parse_filters(String.t()) :: %{required(String.t()) => true} | %{}
  defp maybe_parse_filters(filters) when is_nil(filters) or filters == "", do: %{}

  defp maybe_parse_filters(filters) do
    filters
    |> String.split(",")
    |> Enum.filter(&Enum.member?(@filters, &1))
    |> Enum.map(&String.to_atom(&1))
    |> Enum.into(%{}, &{&1, true})
  end

  def right_add(conn, %{"permission_group" => permission_group, "nickname" => nickname})
      when permission_group in ["moderator", "admin"] do
    user = User.get_cached_by_nickname(nickname)

    info =
      %{}
      |> Map.put("is_" <> permission_group, true)

    info_cng = User.Info.admin_api_update(user.info, info)

    cng =
      user
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_embed(:info, info_cng)

    {:ok, _user} = User.update_and_set_cache(cng)

    json(conn, info)
  end

  def right_add(conn, _) do
    conn
    |> put_status(404)
    |> json(%{error: "No such permission_group"})
  end

  def right_get(conn, %{"nickname" => nickname}) do
    user = User.get_cached_by_nickname(nickname)

    conn
    |> json(%{
      is_moderator: user.info.is_moderator,
      is_admin: user.info.is_admin
    })
  end

  def right_delete(
        %{assigns: %{user: %User{:nickname => admin_nickname}}} = conn,
        %{
          "permission_group" => permission_group,
          "nickname" => nickname
        }
      )
      when permission_group in ["moderator", "admin"] do
    if admin_nickname == nickname do
      conn
      |> put_status(403)
      |> json(%{error: "You can't revoke your own admin status."})
    else
      user = User.get_cached_by_nickname(nickname)

      info =
        %{}
        |> Map.put("is_" <> permission_group, false)

      info_cng = User.Info.admin_api_update(user.info, info)

      cng =
        Ecto.Changeset.change(user)
        |> Ecto.Changeset.put_embed(:info, info_cng)

      {:ok, _user} = User.update_and_set_cache(cng)

      json(conn, info)
    end
  end

  def right_delete(conn, _) do
    conn
    |> put_status(404)
    |> json(%{error: "No such permission_group"})
  end

  def set_activation_status(conn, %{"nickname" => nickname, "status" => status}) do
    with {:ok, status} <- Ecto.Type.cast(:boolean, status),
         %User{} = user <- User.get_cached_by_nickname(nickname),
         {:ok, _} <- User.deactivate(user, !status),
         do: json_response(conn, :no_content, "")
  end

  def relay_follow(conn, %{"relay_url" => target}) do
    with {:ok, _message} <- Relay.follow(target) do
      json(conn, target)
    else
      _ ->
        conn
        |> put_status(500)
        |> json(target)
    end
  end

  def relay_unfollow(conn, %{"relay_url" => target}) do
    with {:ok, _message} <- Relay.unfollow(target) do
      json(conn, target)
    else
      _ ->
        conn
        |> put_status(500)
        |> json(target)
    end
  end

  @doc "Sends registration invite via email"
  def email_invite(%{assigns: %{user: user}} = conn, %{"email" => email} = params) do
    with true <-
           Pleroma.Config.get([:instance, :invites_enabled]) &&
             !Pleroma.Config.get([:instance, :registrations_open]),
         {:ok, invite_token} <- UserInviteToken.create_invite(),
         email <-
           Pleroma.Emails.UserEmail.user_invitation_email(
             user,
             invite_token,
             email,
             params["name"]
           ),
         {:ok, _} <- Pleroma.Emails.Mailer.deliver(email) do
      json_response(conn, :no_content, "")
    end
  end

  @doc "Get a account registeration invite token (base64 string)"
  def get_invite_token(conn, params) do
    options = params["invite"] || %{}
    {:ok, invite} = UserInviteToken.create_invite(options)

    conn
    |> json(invite.token)
  end

  @doc "Get list of created invites"
  def invites(conn, _params) do
    invites = UserInviteToken.list_invites()

    conn
    |> json(AccountView.render("invites.json", %{invites: invites}))
  end

  @doc "Revokes invite by token"
  def revoke_invite(conn, %{"token" => token}) do
    invite = UserInviteToken.find_by_token!(token)
    {:ok, updated_invite} = UserInviteToken.update_invite(invite, %{used: true})

    conn
    |> json(AccountView.render("invite.json", %{invite: updated_invite}))
  end

  @doc "Get a password reset token (base64 string) for given nickname"
  def get_password_reset(conn, %{"nickname" => nickname}) do
    (%User{local: true} = user) = User.get_cached_by_nickname(nickname)
    {:ok, token} = Pleroma.PasswordResetToken.create_token(user)

    conn
    |> json(token.token)
  end

  def errors(conn, {:error, :not_found}) do
    conn
    |> put_status(404)
    |> json("Not found")
  end

  def errors(conn, {:param_cast, _}) do
    conn
    |> put_status(400)
    |> json("Invalid parameters")
  end

  def errors(conn, _) do
    conn
    |> put_status(500)
    |> json("Something went wrong")
  end

  defp page_params(params) do
    {get_page(params["page"]), get_page_size(params["page_size"])}
  end

  defp get_page(page_string) when is_nil(page_string), do: 1

  defp get_page(page_string) do
    case Integer.parse(page_string) do
      {page, _} -> page
      :error -> 1
    end
  end

  defp get_page_size(page_size_string) when is_nil(page_size_string), do: @users_page_size

  defp get_page_size(page_size_string) do
    case Integer.parse(page_size_string) do
      {page_size, _} -> page_size
      :error -> @users_page_size
    end
  end
end
