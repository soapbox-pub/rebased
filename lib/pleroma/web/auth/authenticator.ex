# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Auth.Authenticator do
  @callback get_user(Plug.Conn.t()) :: {:ok, user :: struct()} | {:error, any()}
  @callback create_from_registration(Plug.Conn.t(), registration :: struct()) ::
              {:ok, User.t()} | {:error, any()}
  @callback get_registration(Plug.Conn.t()) :: {:ok, registration :: struct()} | {:error, any()}
  @callback handle_error(Plug.Conn.t(), any()) :: any()
  @callback auth_template() :: String.t() | nil
  @callback oauth_consumer_template() :: String.t() | nil
end
