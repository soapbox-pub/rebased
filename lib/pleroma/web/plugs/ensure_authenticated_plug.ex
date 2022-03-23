# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.EnsureAuthenticatedPlug do
  @moduledoc """
  Ensures _user_ authentication (app-bound user-unbound tokens are not accepted).
  """

  import Plug.Conn
  import Pleroma.Web.TranslationHelpers

  alias Pleroma.User

  use Pleroma.Web, :plug

  def init(options) do
    options
  end

  @impl true
  def perform(
        %{
          assigns: %{
            auth_credentials: %{password: _},
            user: %User{multi_factor_authentication_settings: %{enabled: true}}
          }
        } = conn,
        _
      ) do
    conn
    |> render_error(:forbidden, "Two-factor authentication enabled, you must use a access token.")
    |> halt()
  end

  def perform(%{assigns: %{user: %User{}}} = conn, _) do
    conn
  end

  def perform(conn, _) do
    conn
    |> render_error(:forbidden, "Invalid credentials.")
    |> halt()
  end
end
