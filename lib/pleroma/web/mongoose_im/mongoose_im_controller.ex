# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MongooseIM.MongooseIMController do
  use Pleroma.Web, :controller

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.Plugs.AuthenticationPlug
  alias Pleroma.Web.Plugs.RateLimiter

  plug(RateLimiter, [name: :authentication] when action in [:user_exists, :check_password])
  plug(RateLimiter, [name: :authentication, params: ["user"]] when action == :check_password)

  def user_exists(conn, %{"user" => username}) do
    with %User{} <- Repo.get_by(User, nickname: username, local: true, is_active: true) do
      conn
      |> json(true)
    else
      _ ->
        conn
        |> put_status(:not_found)
        |> json(false)
    end
  end

  def check_password(conn, %{"user" => username, "pass" => password}) do
    with %User{password_hash: password_hash, is_active: true} <-
           Repo.get_by(User, nickname: username, local: true),
         true <- AuthenticationPlug.checkpw(password, password_hash) do
      conn
      |> json(true)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(false)

      _ ->
        conn
        |> put_status(:not_found)
        |> json(false)
    end
  end
end
