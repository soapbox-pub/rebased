# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.OAuthPlug do
  @moduledoc "Performs OAuth authentication by token from params / headers / cookies."

  import Plug.Conn
  import Ecto.Query

  alias Pleroma.Helpers.AuthHelper
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Token

  @realm_reg Regex.compile!("Bearer\:?\s+(.*)$", "i")

  def init(options), do: options

  def call(%{assigns: %{user: %User{}}} = conn, _), do: conn

  def call(conn, _) do
    with {:ok, token_str} <- fetch_token_str(conn) do
      with {:ok, user, user_token} <- fetch_user_and_token(token_str),
           false <- Token.is_expired?(user_token) do
        conn
        |> assign(:token, user_token)
        |> assign(:user, user)
      else
        _ ->
          with {:ok, app, app_token} <- fetch_app_and_token(token_str),
               false <- Token.is_expired?(app_token) do
            conn
            |> assign(:token, app_token)
            |> assign(:app, app)
          else
            _ -> conn
          end
      end
    else
      _ -> conn
    end
  end

  # Gets user by token
  #
  @spec fetch_user_and_token(String.t()) :: {:ok, User.t(), Token.t()} | nil
  defp fetch_user_and_token(token) do
    token_query =
      from(t in Token,
        where: t.token == ^token
      )

    with %Token{user_id: user_id} = token_record <- Repo.one(token_query),
         false <- is_nil(user_id),
         %User{} = user <- User.get_cached_by_id(user_id) do
      {:ok, user, token_record}
    else
      _ -> nil
    end
  end

  @spec fetch_app_and_token(String.t()) :: {:ok, App.t(), Token.t()} | nil
  defp fetch_app_and_token(token) do
    query =
      from(t in Token, where: t.token == ^token, join: app in assoc(t, :app), preload: [app: app])

    with %Token{app: app} = token_record <- Repo.one(query) do
      {:ok, app, token_record}
    end
  end

  # Gets token string from conn (in params / headers / session)
  #
  @spec fetch_token_str(Plug.Conn.t() | list(String.t())) :: :no_token_found | {:ok, String.t()}
  defp fetch_token_str(%Plug.Conn{params: %{"access_token" => access_token}} = _conn) do
    {:ok, access_token}
  end

  defp fetch_token_str(%Plug.Conn{} = conn) do
    headers = get_req_header(conn, "authorization")

    with {:ok, token} <- fetch_token_str(headers) do
      {:ok, token}
    else
      _ -> fetch_token_from_session(conn)
    end
  end

  defp fetch_token_str([token | tail]) do
    trimmed_token = String.trim(token)

    case Regex.run(@realm_reg, trimmed_token) do
      [_, match] -> {:ok, String.trim(match)}
      _ -> fetch_token_str(tail)
    end
  end

  defp fetch_token_str([]), do: :no_token_found

  @spec fetch_token_from_session(Plug.Conn.t()) :: :no_token_found | {:ok, String.t()}
  defp fetch_token_from_session(conn) do
    case AuthHelper.get_session_token(conn) do
      nil -> :no_token_found
      token -> {:ok, token}
    end
  end
end
