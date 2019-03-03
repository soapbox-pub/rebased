# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Auth.Authenticator do
  alias Pleroma.User

  def implementation do
    Pleroma.Config.get(
      Pleroma.Web.Auth.Authenticator,
      Pleroma.Web.Auth.PleromaAuthenticator
    )
  end

  @callback get_user(Plug.Conn.t()) :: {:ok, User.t()} | {:error, any()}
  def get_user(plug), do: implementation().get_user(plug)

  @callback handle_error(Plug.Conn.t(), any()) :: any()
  def handle_error(plug, error), do: implementation().handle_error(plug, error)

  @callback auth_template() :: String.t() | nil
  def auth_template do
    implementation().auth_template() || Pleroma.Config.get(:auth_template, "show.html")
  end
end
