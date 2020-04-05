# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.RenderError do
  @behaviour Plug

  alias OpenApiSpex.Plug.JsonRenderError
  alias Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug

  def call(%{private: %{open_api_spex: %{operation_id: "AccountController.create"}}} = conn, _) do
    conn
    |> Conn.put_status(:bad_request)
    |> Phoenix.Controller.json(%{"error" => "Missing parameters"})
  end

  def call(conn, reason) do
    opts = JsonRenderError.init(reason)

    JsonRenderError.call(conn, opts)
  end
end
