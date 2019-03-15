# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Auth.PleromaAuthenticator do
  alias Comeonin.Pbkdf2
  alias Pleroma.User

  @behaviour Pleroma.Web.Auth.Authenticator

  def get_user(%Plug.Conn{} = _conn, %{
        "authorization" => %{"name" => name, "password" => password}
      }) do
    with {_, %User{} = user} <- {:user, User.get_by_nickname_or_email(name)},
         {_, true} <- {:checkpw, Pbkdf2.checkpw(password, user.password_hash)} do
      {:ok, user}
    else
      error ->
        {:error, error}
    end
  end

  def get_user(%Plug.Conn{} = _conn, _params), do: {:error, :missing_credentials}

  def get_or_create_user_by_oauth(
        %Plug.Conn{assigns: %{ueberauth_auth: %{provider: provider, uid: uid} = auth}},
        _params
      ) do
    user = User.get_by_auth_provider_uid(provider, uid)

    if user do
      {:ok, user}
    else
      info = auth.info
      email = info.email
      nickname = info.nickname

      # TODO: FIXME: connect to existing (non-oauth) account (need a UI flow for that) / generate a random nickname?
      email =
        if email && User.get_by_email(email) do
          nil
        else
          email
        end

      nickname =
        if nickname && User.get_by_nickname(nickname) do
          nil
        else
          nickname
        end

      new_user =
        User.oauth_register_changeset(
          %User{},
          %{
            auth_provider: to_string(provider),
            auth_provider_uid: to_string(uid),
            name: info.name,
            bio: info.description,
            email: email,
            nickname: nickname
          }
        )

      Pleroma.Repo.insert(new_user)
    end
  end

  def get_or_create_user_by_oauth(%Plug.Conn{} = _conn, _params),
    do: {:error, :missing_credentials}

  def handle_error(%Plug.Conn{} = _conn, error) do
    error
  end

  def auth_template, do: nil
end
