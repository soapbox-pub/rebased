# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.EmailListController do
  use Pleroma.Web, :controller

  alias Pleroma.User.MailingList
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  require Logger

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:read:accounts"]} when action in [:subscribers]
  )

  def subscribers(conn, _params) do
    csv = MailingList.generate_csv()

    conn
    |> put_resp_content_type("text/csv")
    |> resp(200, csv)
    |> send_resp()
  end
end
