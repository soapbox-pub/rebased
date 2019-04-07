# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Auth.Authenticator do
  alias Pleroma.Registration
  alias Pleroma.User

  def implementation do
    Pleroma.Config.get(
      Pleroma.Web.Auth.Authenticator,
      Pleroma.Web.Auth.PleromaAuthenticator
    )
  end

  @callback get_user(Plug.Conn.t(), Map.t()) :: {:ok, User.t()} | {:error, any()}
  def get_user(plug, params), do: implementation().get_user(plug, params)

  @callback create_from_registration(Plug.Conn.t(), Map.t(), Registration.t()) ::
              {:ok, User.t()} | {:error, any()}
  def create_from_registration(plug, params, registration),
    do: implementation().create_from_registration(plug, params, registration)

  @callback get_registration(Plug.Conn.t(), Map.t()) ::
              {:ok, Registration.t()} | {:error, any()}
  def get_registration(plug, params),
    do: implementation().get_registration(plug, params)

  @callback handle_error(Plug.Conn.t(), any()) :: any()
  def handle_error(plug, error), do: implementation().handle_error(plug, error)

  @callback auth_template() :: String.t() | nil
  def auth_template do
    # Note: `config :pleroma, :auth_template, "..."` support is deprecated
    implementation().auth_template() ||
      Pleroma.Config.get([:auth, :auth_template], Pleroma.Config.get(:auth_template)) ||
      "show.html"
  end

  @callback oauth_consumer_template() :: String.t() | nil
  def oauth_consumer_template do
    implementation().oauth_consumer_template() ||
      Pleroma.Config.get([:auth, :oauth_consumer_template], "consumer.html")
  end
end
