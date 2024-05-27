# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.Controller do
  use Pleroma.Web, :controller

  alias Pleroma.User
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Pleroma.Web.TwitterAPI.TokenView

  require Logger

  plug(:skip_auth when action == :confirm_email)
  plug(:skip_plug, OAuthScopesPlug when action in [:oauth_tokens, :revoke_token])

  action_fallback(:errors)

  def confirm_email(conn, %{"user_id" => uid, "token" => token}) do
    with %User{} = user <- User.get_cached_by_id(uid),
         true <- user.local and !user.is_confirmed and user.confirmation_token == token,
         {:ok, _} <- User.confirm(user) do
      redirect(conn, to: "/")
    end
  end

  def oauth_tokens(%{assigns: %{user: user}} = conn, _params) do
    with oauth_tokens <- Token.get_user_tokens(user) do
      conn
      |> put_view(TokenView)
      |> render("index.json", %{tokens: oauth_tokens})
    end
  end

  def revoke_token(%{assigns: %{user: user}} = conn, %{"id" => id} = _params) do
    Token.delete_user_token(user, id)

    json_reply(conn, 201, "")
  end

  defp errors(conn, {:param_cast, _}) do
    conn
    |> put_status(400)
    |> json("Invalid parameters")
  end

  defp errors(conn, _) do
    conn
    |> put_status(500)
    |> json("Something went wrong")
  end

  defp json_reply(conn, status, json) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, json)
  end
end
