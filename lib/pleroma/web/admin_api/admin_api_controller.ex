defmodule Pleroma.Web.AdminAPI.AdminAPIController do
  use Pleroma.Web, :controller
  alias Pleroma.{User, Repo}
  alias Pleroma.Web.ActivityPub.Relay

  import Pleroma.Web.ControllerHelper, only: [json_response: 3]

  require Logger

  action_fallback(:errors)

  def user_delete(conn, %{"nickname" => nickname}) do
    user = User.get_by_nickname(nickname)

    if user.local == true do
      User.delete(user)
    else
      User.delete(user)
    end

    conn
    |> json(nickname)
  end

  def user_create(
        conn,
        %{"nickname" => nickname, "email" => email, "password" => password}
      ) do
    new_user = %{
      nickname: nickname,
      name: nickname,
      email: email,
      password: password,
      password_confirmation: password,
      bio: "."
    }

    User.register_changeset(%User{}, new_user)
    |> Repo.insert!()

    conn
    |> json(new_user.nickname)
  end

  def tag_users(conn, %{"nicknames" => nicknames, "tags" => tags}) do
    with {:ok, _} <- User.tag(nicknames, tags),
         do: json_response(conn, :no_content, "")
  end

  def untag_users(conn, %{"nicknames" => nicknames, "tags" => tags}) do
    with {:ok, _} <- User.untag(nicknames, tags),
         do: json_response(conn, :no_content, "")
  end

  def right_add(conn, %{"permission_group" => permission_group, "nickname" => nickname})
      when permission_group in ["moderator", "admin"] do
    user = User.get_by_nickname(nickname)

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
    user = User.get_by_nickname(nickname)

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
      user = User.get_by_nickname(nickname)

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
         {:ok, invite_token} <- Pleroma.UserInviteToken.create_token(),
         email <-
           Pleroma.UserEmail.user_invitation_email(user, invite_token, email, params["name"]),
         {:ok, _} <- Pleroma.Mailer.deliver(email) do
      json_response(conn, :no_content, "")
    end
  end

  @doc "Get a account registeration invite token (base64 string)"
  def get_invite_token(conn, _params) do
    {:ok, token} = Pleroma.UserInviteToken.create_token()

    conn
    |> json(token.token)
  end

  @doc "Get a password reset token (base64 string) for given nickname"
  def get_password_reset(conn, %{"nickname" => nickname}) do
    (%User{local: true} = user) = User.get_by_nickname(nickname)
    {:ok, token} = Pleroma.PasswordResetToken.create_token(user)

    conn
    |> json(token.token)
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
end
