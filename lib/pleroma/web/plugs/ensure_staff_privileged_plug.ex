# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.EnsureStaffPrivilegedPlug do
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

  def call(%{assigns: %{user: %User{is_admin: true}}} = conn, _), do: conn

  def call(%{assigns: %{user: %User{is_moderator: true}}} = conn, _) do
    if Config.get!([:instance, :privileged_staff]) do
      conn
    else
      conn
      |> render_error(:forbidden, "User is not an admin.")
      |> halt()
    end
  end

  def call(conn, _) do
    conn
    |> render_error(:forbidden, "User is not a staff member.")
    |> halt()
  end
end
