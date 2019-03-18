# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Auth.PleromaAuthenticator do
  alias Comeonin.Pbkdf2
  alias Pleroma.User
  alias Pleroma.Registration
  alias Pleroma.Repo

  @behaviour Pleroma.Web.Auth.Authenticator

  def get_user(%Plug.Conn{} = _conn, params) do
    {name, password} =
      case params do
        %{"authorization" => %{"name" => name, "password" => password}} ->
          {name, password}

        %{"grant_type" => "password", "username" => name, "password" => password} ->
          {name, password}
      end

    with {_, %User{} = user} <- {:user, User.get_by_nickname_or_email(name)},
         {_, true} <- {:checkpw, Pbkdf2.checkpw(password, user.password_hash)} do
      {:ok, user}
    else
      error ->
        {:error, error}
    end
  end

  def get_by_external_registration(
        %Plug.Conn{assigns: %{ueberauth_auth: %{provider: provider, uid: uid} = auth}},
        _params
      ) do
    registration = Registration.get_by_provider_uid(provider, uid)

    if registration do
      user = Repo.preload(registration, :user).user
      {:ok, user}
    else
      info = auth.info
      email = info.email
      nickname = info.nickname

      # Note: nullifying email in case this email is already taken
      email =
        if email && User.get_by_email(email) do
          nil
        else
          email
        end

      # Note: generating a random numeric suffix to nickname in case this nickname is already taken
      nickname =
        if nickname && User.get_by_nickname(nickname) do
          "#{nickname}#{:os.system_time()}"
        else
          nickname
        end

      random_password = :crypto.strong_rand_bytes(64) |> Base.encode64()

      with {:ok, new_user} <-
             User.register_changeset(
               %User{},
               %{
                 name: info.name,
                 bio: info.description,
                 email: email,
                 nickname: nickname,
                 password: random_password,
                 password_confirmation: random_password
               },
               external: true,
               confirmed: true
             )
             |> Repo.insert(),
           {:ok, _} <-
             Registration.changeset(%Registration{}, %{
               user_id: new_user.id,
               provider: to_string(provider),
               uid: to_string(uid),
               info: %{nickname: info.nickname, email: info.email}
             })
             |> Repo.insert() do
        {:ok, new_user}
      end
    end
  end

  def get_by_external_registration(%Plug.Conn{} = _conn, _params),
    do: {:error, :missing_credentials}

  def handle_error(%Plug.Conn{} = _conn, error) do
    error
  end

  def auth_template, do: nil
end
