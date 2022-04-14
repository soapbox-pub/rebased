# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.HTTPSignaturePlug do
  import Plug.Conn
  import Phoenix.Controller, only: [get_format: 1, text: 2]

  alias Pleroma.Config
  alias Pleroma.Web.ActivityPub.MRF

  require Logger

  def init(options) do
    options
  end

  def call(%{assigns: %{valid_signature: true}} = conn, _opts) do
    conn
  end

  def call(conn, _opts) do
    if get_format(conn) == "activity+json" do
      conn
      |> maybe_assign_valid_signature()
      |> maybe_assign_actor_id()
      |> maybe_require_signature()
      |> maybe_filter_requests()
    else
      conn
    end
  end

  defp maybe_assign_valid_signature(conn) do
    if has_signature_header?(conn) do
      # set (request-target) header to the appropriate value
      # we also replace the digest header with the one we computed
      request_target = String.downcase("#{conn.method}") <> " #{conn.request_path}"

      conn =
        conn
        |> put_req_header("(request-target)", request_target)
        |> case do
          %{assigns: %{digest: digest}} = conn -> put_req_header(conn, "digest", digest)
          conn -> conn
        end

      assign(conn, :valid_signature, HTTPSignatures.validate_conn(conn))
    else
      Logger.debug("No signature header!")
      conn
    end
  end

  defp maybe_assign_actor_id(%{assigns: %{valid_signature: true}} = conn) do
    adapter = Application.get_env(:http_signatures, :adapter)

    {:ok, actor_id} = adapter.get_actor_id(conn)

    assign(conn, :actor_id, actor_id)
  end

  defp maybe_assign_actor_id(conn), do: conn

  defp has_signature_header?(conn) do
    conn |> get_req_header("signature") |> Enum.at(0, false)
  end

  defp maybe_require_signature(%{assigns: %{valid_signature: true}} = conn), do: conn

  defp maybe_require_signature(conn) do
    if Pleroma.Config.get([:activitypub, :authorized_fetch_mode], false) do
      conn
      |> put_status(:unauthorized)
      |> text("Request not signed")
      |> halt()
    else
      conn
    end
  end

  defp maybe_filter_requests(%{halted: true} = conn), do: conn

  defp maybe_filter_requests(conn) do
    if Pleroma.Config.get([:activitypub, :authorized_fetch_mode], false) do
      %{host: host} = URI.parse(conn.assigns.actor_id)

      if MRF.subdomain_match?(rejected_domains(), host) do
        conn
        |> put_status(:unauthorized)
        |> halt()
      else
        conn
      end
    else
      conn
    end
  end

  defp rejected_domains do
    Config.get([:instance, :rejected_instances])
    |> Pleroma.Web.ActivityPub.MRF.instance_list_from_tuples()
    |> Pleroma.Web.ActivityPub.MRF.subdomains_regex()
  end
end
