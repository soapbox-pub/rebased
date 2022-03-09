# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Auth.Helpers do
  alias Pleroma.User

  @doc "Gets user by nickname or email for auth."
  @spec fetch_user(String.t()) :: User.t() | nil
  def fetch_user(name) do
    User.get_by_nickname_or_email(name)
  end

  # Gets name and password from conn
  #
  @spec fetch_credentials(Plug.Conn.t() | map()) ::
          {:ok, {name :: any, password :: any}} | {:error, :invalid_credentials}
  def fetch_credentials(%Plug.Conn{params: params} = _),
    do: fetch_credentials(params)

  def fetch_credentials(params) do
    case params do
      %{"authorization" => %{"name" => name, "password" => password}} ->
        {:ok, {name, password}}

      %{"grant_type" => "password", "username" => name, "password" => password} ->
        {:ok, {name, password}}

      _ ->
        {:error, :invalid_credentials}
    end
  end
end
