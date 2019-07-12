# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.FallbackController do
  use Pleroma.Web, :controller
  alias Pleroma.Web.OAuth.OAuthController

  def call(conn, {:register, :generic_error}) do
    conn
    |> put_status(:internal_server_error)
    |> put_flash(
      :error,
      dgettext("errors", "Unknown error, please check the details and try again.")
    )
    |> OAuthController.registration_details(conn.params)
  end

  def call(conn, {:register, _error}) do
    conn
    |> put_status(:unauthorized)
    |> put_flash(:error, dgettext("errors", "Invalid Username/Password"))
    |> OAuthController.registration_details(conn.params)
  end

  def call(conn, _error) do
    conn
    |> put_status(:unauthorized)
    |> put_flash(:error, dgettext("errors", "Invalid Username/Password"))
    |> OAuthController.authorize(conn.params)
  end
end
