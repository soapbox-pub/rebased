# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.EnsurePrivilegedPlug do
  @moduledoc """
  Ensures staff are privileged enough to do certain tasks.
  """
  import Pleroma.Web.TranslationHelpers
  import Plug.Conn

  alias Pleroma.Config
  alias Pleroma.User

  def init(options) do
    options
  end

  def call(%{assigns: %{user: %User{is_admin: false, is_moderator: false}}} = conn, _) do
    conn
    |> render_error(:forbidden, "User isn't privileged.")
    |> halt()
  end

  def call(
        %{assigns: %{user: %User{is_admin: is_admin, is_moderator: is_moderator}}} = conn,
        priviledge
      ) do
    if (is_admin and priviledge in Config.get([:instance, :admin_privileges])) or
         (is_moderator and priviledge in Config.get([:instance, :moderator_privileges])) do
      conn
    else
      conn
      |> render_error(:forbidden, "User isn't privileged.")
      |> halt()
    end
  end

  def call(conn, _) do
    conn
    |> render_error(:forbidden, "User isn't privileged.")
    |> halt()
  end
end
