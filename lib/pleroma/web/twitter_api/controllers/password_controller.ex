# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.PasswordController do
  @moduledoc """
  The module containts functions for reset password.
  """

  use Pleroma.Web, :controller

  require Logger

  alias Pleroma.PasswordResetToken
  alias Pleroma.Repo
  alias Pleroma.User

  def reset(conn, %{"token" => token}) do
    with %{used: false} = token <- Repo.get_by(PasswordResetToken, %{token: token}),
         %User{} = user <- User.get_cached_by_id(token.user_id) do
      render(conn, "reset.html", %{
        token: token,
        user: user
      })
    else
      _e -> render(conn, "invalid_token.html")
    end
  end

  def do_reset(conn, %{"data" => data}) do
    with {:ok, _} <- PasswordResetToken.reset_password(data["token"], data) do
      render(conn, "reset_success.html")
    else
      _e -> render(conn, "reset_failed.html")
    end
  end
end
