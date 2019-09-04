# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.FallbackController do
  use Pleroma.Web, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    error_message =
      changeset
      |> Ecto.Changeset.traverse_errors(fn {message, _opt} -> message end)
      |> Enum.map_join(", ", fn {_k, v} -> v end)

    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: error_message})
  end

  def call(conn, {:error, :not_found}) do
    render_error(conn, :not_found, "Record not found")
  end

  def call(conn, {:error, error_message}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: error_message})
  end

  def call(conn, _) do
    conn
    |> put_status(:internal_server_error)
    |> json(dgettext("errors", "Something went wrong"))
  end
end
