defmodule Pleroma.Web.AdminAPI.AdminAPIController do
  use Pleroma.Web, :controller
  alias Pleroma.{User, Repo}
  alias Pleroma.Web.ActivityPub.Relay

  require Logger

  action_fallback(:errors)

  def user_delete(conn, %{nickname: nickname}) do
    user = User.get_by_nickname(nickname)

    if user[:local] == true do
      User.delete(user)
    else
      User.delete(user)
    end

    conn
    |> send(200)
  end

  def user_create(
        conn,
        %{user: %{nickname: nickname, email: email, password: password} = user}
      ) do
    new_user = %User{
      nickname: nickname,
      name: user.name || nickname,
      email: email,
      password: password,
      password_confirmation: password,
      bio: user.bio || "."
    }

    User.register_changeset(%User{}, new_user)

    Repo.insert!(user)

    conn
    |> send(200)
  end

  def relay_follow(conn, %{relay_url: target}) do
    :ok = Relay.follow(target)

    conn
    |> send(200)
  end

  def relay_unfollow(conn, %{relay_url: target}) do
    :ok = Relay.unfollow(target)

    conn
    |> send(200)
  end

  def get_invite_token(conn, _params) do
    {:ok, token} <- Pleroma.UserInviteToken.create_token()

    conn
    |> puts(token)
  end

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
