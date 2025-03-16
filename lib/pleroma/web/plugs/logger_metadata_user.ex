# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.LoggerMetadataUser do
  alias Pleroma.User

  def init(opts), do: opts

  def call(%{assigns: %{user: user = %User{}}} = conn, _) do
    Logger.metadata(user: user.nickname)
    conn
  end

  def call(conn, _) do
    conn
  end
end
