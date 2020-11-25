# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Helpers.AuthHelper do
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Plug.Conn

  import Plug.Conn

  @oauth_token_session_key :oauth_token

  @doc """
  Skips OAuth permissions (scopes) checks, assigns nil `:token`.
  Intended to be used with explicit authentication and only when OAuth token cannot be determined.
  """
  def skip_oauth(conn) do
    conn
    |> assign(:token, nil)
    |> OAuthScopesPlug.skip_plug()
  end

  def drop_auth_info(conn) do
    conn
    |> assign(:user, nil)
    |> assign(:token, nil)
  end

  def get_session_token(%Conn{} = conn) do
    get_session(conn, @oauth_token_session_key)
  end

  def put_session_token(%Conn{} = conn, token) when is_binary(token) do
    put_session(conn, @oauth_token_session_key, token)
  end

  def delete_session_token(%Conn{} = conn) do
    delete_session(conn, @oauth_token_session_key)
  end
end
