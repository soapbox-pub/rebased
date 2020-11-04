# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.OAuthView do
  use Pleroma.Web, :view
  import Phoenix.HTML.Form

  alias Pleroma.Web.OAuth.Token.Utils

  def render("token.json", %{token: token} = opts) do
    response = %{
      token_type: "Bearer",
      access_token: token.token,
      refresh_token: token.refresh_token,
      expires_in: expires_in(),
      scope: Enum.join(token.scopes, " "),
      created_at: Utils.format_created_at(token)
    }

    if user = opts[:user] do
      response
      |> Map.put(:me, user.ap_id)
    else
      response
    end
  end

  defp expires_in, do: Pleroma.Config.get([:oauth2, :token_expires_in], 600)
end
