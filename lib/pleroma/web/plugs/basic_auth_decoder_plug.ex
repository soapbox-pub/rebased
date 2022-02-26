# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.BasicAuthDecoderPlug do
  @moduledoc """
  Decodes HTTP Basic Auth information and assigns `:auth_credentials`.

  NOTE: no checks are performed at this step, auth_credentials/username could be easily faked.
  """

  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _opts) do
    with ["Basic " <> header] <- get_req_header(conn, "authorization"),
         {:ok, userinfo} <- Base.decode64(header),
         [username, password] <- String.split(userinfo, ":", parts: 2) do
      conn
      |> assign(:auth_credentials, %{
        username: username,
        password: password
      })
    else
      _ -> conn
    end
  end
end
