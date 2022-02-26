# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Auth.WrapperAuthenticator do
  @behaviour Pleroma.Web.Auth.Authenticator

  defp implementation do
    Pleroma.Config.get(
      Pleroma.Web.Auth.Authenticator,
      Pleroma.Web.Auth.PleromaAuthenticator
    )
  end

  @impl true
  def get_user(plug), do: implementation().get_user(plug)

  @impl true
  def create_from_registration(plug, registration),
    do: implementation().create_from_registration(plug, registration)

  @impl true
  def get_registration(plug), do: implementation().get_registration(plug)

  @impl true
  def handle_error(plug, error),
    do: implementation().handle_error(plug, error)

  @impl true
  def auth_template do
    # Note: `config :pleroma, :auth_template, "..."` support is deprecated
    implementation().auth_template() ||
      Pleroma.Config.get([:auth, :auth_template], Pleroma.Config.get(:auth_template)) ||
      "show.html"
  end

  @impl true
  def oauth_consumer_template do
    implementation().oauth_consumer_template() ||
      Pleroma.Config.get([:auth, :oauth_consumer_template], "consumer.html")
  end
end
