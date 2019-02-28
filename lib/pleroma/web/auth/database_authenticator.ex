# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Auth.DatabaseAuthenticator do
  alias Pleroma.User

  def implementation do
    Pleroma.Config.get(
      Pleroma.Web.Auth.DatabaseAuthenticator,
      Pleroma.Web.Auth.PleromaDatabaseAuthenticator
    )
  end

  @callback get_user(Plug.Conn.t()) :: {:ok, User.t()} | {:error, any()}
  def get_user(plug), do: implementation().get_user(plug)

  @callback handle_error(Plug.Conn.t(), any()) :: any()
  def handle_error(plug, error), do: implementation().handle_error(plug, error)
end
