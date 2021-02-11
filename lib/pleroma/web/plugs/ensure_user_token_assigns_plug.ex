# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.EnsureUserTokenAssignsPlug do
  import Plug.Conn

  alias Pleroma.Helpers.AuthHelper
  alias Pleroma.User
  alias Pleroma.Web.OAuth.Token

  @moduledoc "Ensures presence and consistency of :user and :token assigns."

  def init(opts) do
    opts
  end

  def call(%{assigns: %{user: %User{id: user_id}} = assigns} = conn, _) do
    with %Token{user_id: ^user_id} <- assigns[:token] do
      conn
    else
      %Token{} ->
        # A safety net for abnormal (unexpected) scenario: :token belongs to another user
        AuthHelper.drop_auth_info(conn)

      _ ->
        assign(conn, :token, nil)
    end
  end

  # App-bound token case (obtained with client_id and client_secret)
  def call(%{assigns: %{token: %Token{user_id: nil}}} = conn, _) do
    assign(conn, :user, nil)
  end

  def call(conn, _) do
    conn
    |> assign(:user, nil)
    |> assign(:token, nil)
  end
end
