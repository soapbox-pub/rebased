# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.UserEnabledPlug do
  import Plug.Conn
  alias Pleroma.User

  def init(options) do
    options
  end

  def call(%{assigns: %{user: %User{} = user}} = conn, _) do
    case User.account_status(user) do
      :active -> conn
      _ -> assign(conn, :user, nil)
    end
  end

  def call(conn, _) do
    conn
  end
end
