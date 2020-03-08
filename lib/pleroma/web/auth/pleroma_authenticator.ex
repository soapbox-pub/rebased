# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Auth.PleromaAuthenticator do
  alias Pleroma.Plugs.AuthenticationPlug
  alias Pleroma.Registration
  alias Pleroma.Repo
  alias Pleroma.User

  import Pleroma.Web.Auth.Authenticator,
    only: [fetch_credentials: 1, fetch_user: 1]

  @behaviour Pleroma.Web.Auth.Authenticator

  def get_user(%Plug.Conn{} = conn) do
    with {:ok, {name, password}} <- fetch_credentials(conn),
         {_, %User{} = user} <- {:user, fetch_user(name)},
         {_, true} <- {:checkpw, AuthenticationPlug.checkpw(password, user.password_hash)} do
      {:ok, user}
    else
      error ->
        {:error, error}
    end
  end

  @doc """
  Gets or creates Pleroma.Registration record from Ueberauth assigns.
  Note: some strategies (like `keycloak`) might need extra configuration to fill `uid` from callback response —
    see [`docs/config.md`](docs/config.md).
  """
  def get_registration(%Plug.Conn{assigns: %{ueberauth_auth: %{uid: nil}}}),
    do: {:error, :missing_uid}

  def get_registration(%Plug.Conn{
        assigns: %{ueberauth_auth: %{provider: provider, uid: uid} = auth}
      }) do
    registration = Registration.get_by_provider_uid(provider, uid)

    if registration do
      {:ok, registration}
    else
      info = auth.info

      %Registration{}
      |> Registration.changeset(%{
        provider: to_string(provider),
        uid: to_string(uid),
        info: %{
          "nickname" => info.nickname,
          "email" => info.email,
          "name" => info.name,
          "description" => info.description
        }
      })
      |> Repo.insert()
    end
  end

  def get_registration(%Plug.Conn{} = _conn), do: {:error, :missing_credentials}

  @doc "Creates Pleroma.User record basing on params and Pleroma.Registration record."
  def create_from_registration(
        %Plug.Conn{params: %{"authorization" => registration_attrs}},
        %Registration{} = registration
      ) do
    nickname = value([registration_attrs["nickname"], Registration.nickname(registration)])
    email = value([registration_attrs["email"], Registration.email(registration)])
    name = value([registration_attrs["name"], Registration.name(registration)]) || nickname
    bio = value([registration_attrs["bio"], Registration.description(registration)])

    random_password = :crypto.strong_rand_bytes(64) |> Base.encode64()

    with {:ok, new_user} <-
           User.register_changeset(
             %User{},
             %{
               email: email,
               nickname: nickname,
               name: name,
               bio: bio,
               password: random_password,
               password_confirmation: random_password
             },
             external: true,
             need_confirmation: false
           )
           |> Repo.insert(),
         {:ok, _} <-
           Registration.changeset(registration, %{user_id: new_user.id}) |> Repo.update() do
      {:ok, new_user}
    end
  end

  defp value(list), do: Enum.find(list, &(to_string(&1) != ""))

  def handle_error(%Plug.Conn{} = _conn, error) do
    error
  end

  def auth_template, do: nil

  def oauth_consumer_template, do: nil
end
