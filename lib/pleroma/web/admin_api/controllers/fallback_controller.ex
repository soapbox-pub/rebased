# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.FallbackController do
  use Pleroma.Web, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: dgettext("errors", "Not found")})
  end

  def call(conn, {:error, reason}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: reason})
  end

  def call(conn, {:errors, errors}) do
    conn
    |> put_status(:bad_request)
    |> json(%{errors: errors})
  end

  def call(conn, {:param_cast, _}) do
    conn
    |> put_status(:bad_request)
    |> json(dgettext("errors", "Invalid parameters"))
  end

  def call(conn, _) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{error: dgettext("errors", "Something went wrong")})
  end
end
