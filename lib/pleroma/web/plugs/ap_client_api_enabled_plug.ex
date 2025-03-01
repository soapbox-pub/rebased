# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.APClientApiEnabledPlug do
  import Plug.Conn
  import Phoenix.Controller, only: [text: 2]

  @config_impl Application.compile_env(:pleroma, [__MODULE__, :config_impl], Pleroma.Config)
  @enabled_path [:activitypub, :client_api_enabled]

  def init(options \\ []), do: Map.new(options)

  def call(conn, %{allow_server: true}) do
    if @config_impl.get(@enabled_path, false) do
      conn
    else
      conn
      |> assign(:user, nil)
      |> assign(:token, nil)
    end
  end

  def call(conn, _) do
    if @config_impl.get(@enabled_path, false) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> text("C2S not enabled")
      |> halt()
    end
  end
end
