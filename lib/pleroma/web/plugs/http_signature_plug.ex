# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.HTTPSignaturePlug do
  alias Pleroma.Helpers.InetHelper

  import Plug.Conn
  import Phoenix.Controller, only: [get_format: 1, text: 2]

  alias Pleroma.Web.ActivityPub.MRF

  require Logger

  @config_impl Application.compile_env(:pleroma, [__MODULE__, :config_impl], Pleroma.Config)
  @http_signatures_impl Application.compile_env(
                          :pleroma,
                          [__MODULE__, :http_signatures_impl],
                          HTTPSignatures
                        )

  def init(options) do
    options
  end

  def call(%{assigns: %{valid_signature: true}} = conn, _opts) do
    conn
  end

  def call(conn, _opts) do
    if get_format(conn) in ["json", "activity+json"] do
      conn
      |> maybe_assign_valid_signature()
      |> maybe_assign_actor_id()
      |> maybe_require_signature()
      |> maybe_filter_requests()
    else
      conn
    end
  end

  defp validate_signature(conn, request_target) do
    # Newer drafts for HTTP signatures now use @request-target instead of the
    # old (request-target). We'll now support both for incoming signatures.
    conn =
      conn
      |> put_req_header("(request-target)", request_target)
      |> put_req_header("@request-target", request_target)

    @http_signatures_impl.validate_conn(conn)
  end

  defp validate_signature(conn) do
    # This (request-target) is non-standard, but many implementations do it
    # this way due to a misinterpretation of
    # https://datatracker.ietf.org/doc/html/draft-cavage-http-signatures-06
    # "path" was interpreted as not having the query, though later examples
    # show that it must be the absolute path + query. This behavior is kept to
    # make sure most software (Pleroma itself, Mastodon, and probably others)
    # do not break.
    request_target = String.downcase("#{conn.method}") <> " #{conn.request_path}"

    # This is the proper way to build the @request-target, as expected by
    # many HTTP signature libraries, clarified in the following draft:
    # https://www.ietf.org/archive/id/draft-ietf-httpbis-message-signatures-11.html#section-2.2.6
    # It is the same as before, but containing the query part as well.
    proper_target = request_target <> "?#{conn.query_string}"

    cond do
      # Normal, non-standard behavior but expected by Pleroma and more.
      validate_signature(conn, request_target) ->
        true

      # Has query string and the previous one failed: let's try the standard.
      conn.query_string != "" ->
        validate_signature(conn, proper_target)

      # If there's no query string and signature fails, it's rotten.
      true ->
        false
    end
  end

  defp maybe_assign_valid_signature(conn) do
    if has_signature_header?(conn) do
      # we replace the digest header with the one we computed in DigestPlug
      conn =
        case conn do
          %{assigns: %{digest: digest}} = conn -> put_req_header(conn, "digest", digest)
          conn -> conn
        end

      assign(conn, :valid_signature, validate_signature(conn))
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

  defp maybe_require_signature(%{remote_ip: remote_ip} = conn) do
    if @config_impl.get([:activitypub, :authorized_fetch_mode], false) do
      exceptions =
        @config_impl.get([:activitypub, :authorized_fetch_mode_exceptions], [])
        |> Enum.map(&InetHelper.parse_cidr/1)

      if Enum.any?(exceptions, fn x -> InetCidr.contains?(x, remote_ip) end) do
        conn
      else
        conn
        |> put_status(:unauthorized)
        |> text("Request not signed")
        |> halt()
      end
    else
      conn
    end
  end

  defp maybe_filter_requests(%{halted: true} = conn), do: conn

  defp maybe_filter_requests(conn) do
    if @config_impl.get([:activitypub, :authorized_fetch_mode], false) and
         conn.assigns[:actor_id] do
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
    @config_impl.get([:instance, :rejected_instances])
    |> Pleroma.Web.ActivityPub.MRF.instance_list_from_tuples()
    |> Pleroma.Web.ActivityPub.MRF.subdomains_regex()
  end
end
