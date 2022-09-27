# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.SetApplicationPlug do
  import Plug.Conn, only: [assign: 3]

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.OAuth.Token

  def init(_), do: nil

  def call(conn, _) do
    assign(conn, :application, get_application(conn))
  end

  defp get_application(%{assigns: %{token: %Token{user: %User{} = user} = token}} = _conn) do
    if user.disclose_client do
      %{client_name: client_name, website: website} = Repo.preload(token, :app).app
      %{type: "Application", name: client_name, url: website}
    else
      nil
    end
  end

  defp get_application(_), do: nil
end
