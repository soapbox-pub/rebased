# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.EmailListController do
  use Pleroma.Web, :controller

  alias Pleroma.User.EmailList
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  require Logger

  plug(OAuthScopesPlug, %{scopes: ["admin:read:accounts"]})

  def subscribers(conn, _params) do
    csv = EmailList.generate_csv(:subscribers)

    conn
    |> put_resp_content_type("text/csv")
    |> resp(200, csv)
    |> send_resp()
  end

  def unsubscribers(conn, _params) do
    csv = EmailList.generate_csv(:unsubscribers)

    conn
    |> put_resp_content_type("text/csv")
    |> resp(200, csv)
    |> send_resp()
  end
end
