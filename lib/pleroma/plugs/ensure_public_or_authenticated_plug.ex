# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug do
  import Plug.Conn
  alias Pleroma.Config
  alias Pleroma.User

  def init(options) do
    options
  end

  def call(conn, _) do
    public? = Config.get!([:instance, :public])

    case {public?, conn} do
      {true, _} ->
        conn

      {false, %{assigns: %{user: %User{}}}} ->
        conn

      {false, _} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Jason.encode!(%{error: "This resource requires authentication."}))
        |> halt
    end
  end
end
