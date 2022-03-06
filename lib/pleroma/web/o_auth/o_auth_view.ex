# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.OAuthView do
  use Pleroma.Web, :view
  import Phoenix.HTML.Form

  alias Pleroma.Web.OAuth.Token.Utils

  def render("token.json", %{token: token} = opts) do
    response = %{
      id: token.id,
      token_type: "Bearer",
      access_token: token.token,
      refresh_token: token.refresh_token,
      expires_in: NaiveDateTime.diff(token.valid_until, NaiveDateTime.utc_now()),
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
end
