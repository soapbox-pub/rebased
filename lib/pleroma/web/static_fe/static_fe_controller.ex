# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.StaticFE.StaticFEController do
  use Pleroma.Web, :controller

  alias Pleroma.Web.StaticFE.ActivityRepresenter
  alias Pleroma.Web.StaticFE.UserRepresenter

  require Logger

  def show_notice(conn, %{"notice_id" => notice_id}) do
    with {:ok, data} <- ActivityRepresenter.represent(notice_id) do
      conn
      |> put_layout(:static_fe)
      |> put_status(200)
      |> put_view(Pleroma.Web.StaticFE.StaticFEView)
      |> render("notice.html", %{data: data})
    else
      {:error, nil} ->
        conn
        |> put_status(404)
        |> text("Not found")
    end
  end

  def show_user(conn, %{"username_or_id" => username_or_id}) do
    with {:ok, data} <- UserRepresenter.represent(username_or_id) do
      conn
      |> put_layout(:static_fe)
      |> put_status(200)
      |> put_view(Pleroma.Web.StaticFE.StaticFEView)
      |> render("profile.html", %{data: data})
    else
      {:error, nil} ->
        conn
        |> put_status(404)
        |> text("Not found")
    end
  end

  def show(%{path_info: ["notice", notice_id]} = conn, _params),
    do: show_notice(conn, %{"notice_id" => notice_id})

  def show(%{path_info: ["users", user_id]} = conn, _params),
    do: show_user(conn, %{"username_or_id" => user_id})

  def show(%{path_info: [user_id]} = conn, _params),
    do: show_user(conn, %{"username_or_id" => user_id})

  # Fallback for unhandled types
  def show(conn, _params) do
    conn
    |> put_status(404)
    |> text("Not found")
  end
end
