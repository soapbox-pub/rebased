# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.HTTPSignaturePlug do
  alias Pleroma.Web.ActivityPub.Utils
  import Plug.Conn
  require Logger

  def init(options) do
    options
  end

  def call(%{assigns: %{valid_signature: true}} = conn, _opts) do
    conn
  end

  def call(conn, _opts) do
    user = Utils.get_ap_id(conn.params["actor"])
    Logger.debug("Checking sig for #{user}")
    [signature | _] = get_req_header(conn, "signature")

    cond do
      signature && String.contains?(signature, user) ->
        # set (request-target) header to the appropriate value
        # we also replace the digest header with the one we computed
        conn =
          conn
          |> put_req_header(
            "(request-target)",
            String.downcase("#{conn.method}") <> " #{conn.request_path}"
          )

        conn =
          if conn.assigns[:digest] do
            conn
            |> put_req_header("digest", conn.assigns[:digest])
          else
            conn
          end

        assign(conn, :valid_signature, HTTPSignatures.validate_conn(conn))

      signature ->
        Logger.debug("Signature not from actor")
        assign(conn, :valid_signature, false)

      true ->
        Logger.debug("No signature header!")
        conn
    end
  end
end
