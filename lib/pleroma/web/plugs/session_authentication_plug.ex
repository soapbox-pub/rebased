# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.SessionAuthenticationPlug do
  @moduledoc """
  Authenticates user by session-stored `:user_id` and request-contained username.
  Username can be provided via HTTP Basic Auth (the password is not checked and can be anything).
  """

  import Plug.Conn

  alias Pleroma.Helpers.AuthHelper

  def init(options) do
    options
  end

  def call(%{assigns: %{user: %Pleroma.User{}}} = conn, _), do: conn

  def call(conn, _) do
    with saved_user_id <- get_session(conn, :user_id),
         %{auth_user: %{id: ^saved_user_id}} <- conn.assigns do
      conn
      |> assign(:user, conn.assigns.auth_user)
      |> AuthHelper.skip_oauth()
    else
      _ -> conn
    end
  end
end
