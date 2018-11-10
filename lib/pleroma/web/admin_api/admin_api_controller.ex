defmodule Pleroma.Web.AdminAPI.AdminAPIController do
  use Pleroma.Web, :controller
  alias Pleroma.{User, Repo}
  alias Pleroma.Web.ActivityPub.Relay

  require Logger

  action_fallback(:errors)

  def user_delete(conn, %{"nickname" => nickname}) do
    user = User.get_by_nickname(nickname)

    if user[:local] == true do
      User.delete(user)
    else
      User.delete(user)
    end

    conn
    |> json(nickname)
  end

  def user_create(conn, %{
        user: %{"nickname" => nickname, "email" => email, "password" => password} = user
      }) do
    new_user = %User{
      nickname: nickname,
      name: user.name || nickname,
      email: email,
      password: password,
      password_confirmation: password,
      bio: user.bio || "."
    }

    User.register_changeset(%User{}, new_user)

    Repo.insert!(new_user)

    conn
    |> json(new_user.nickname)
  end

  def right_add(conn, %{"right" => right, "nickname" => nickname})
      when right in ["moderator", "admin"] do
    user = User.get_by_nickname(nickname)

    info =
      user.info
      |> Map.put("is_" <> right, true)

    cng = User.info_changeset(user, %{info: info})
    {:ok, user} = User.update_and_set_cache(cng)

    conn
    |> json(user.info)
  end

  def right_get(conn, %{"nickname" => nickname}) do
    user = User.get_by_nickname(nickname)

    conn
    |> json(user.info)
  end

  def right_add(conn, _) do
    conn
    |> put_status(404)
    |> json(%{error: "No such right"})
  end

  def right_delete(
        %{assigns: %{user: %User{:nickname => admin_nickname}}} = conn,
        %{
          "right" => right,
          "nickname" => nickname
        }
      )
      when right in ["moderator", "admin"] do
    if admin_nickname == nickname do
      conn
      |> post_status(403)
      |> json(%{error: "You can't revoke your own admin status."})
    else
      user = User.get_by_nickname(nickname)

      info =
        user.info
        |> Map.put("is_" <> right, false)

      cng = User.info_changeset(user, %{info: info})
      {:ok, user} = User.update_and_set_cache(cng)

      conn
      |> json(user.info)
    end
  end

  def right_delete(conn, _) do
    conn
    |> put_status(404)
    |> json(%{error: "No such right"})
  end

  def relay_follow(conn, %{"relay_url" => target}) do
    :ok = Relay.follow(target)

    conn
    |> json(target)
  end

  def relay_unfollow(conn, %{"relay_url" => target}) do
    :ok = Relay.unfollow(target)

    conn
    |> json(target)
  end

  @shortdoc "Get a account registeration invite token (base64 string)"
  def get_invite_token(conn, _params) do
    {:ok, token} = Pleroma.UserInviteToken.create_token()

    conn
    |> json(token.token)
  end

  @shortdoc "Get a password reset token (base64 string) for given nickname"
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
