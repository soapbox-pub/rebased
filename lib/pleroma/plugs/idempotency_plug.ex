# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.IdempotencyPlug do
  import Phoenix.Controller, only: [json: 2]
  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  # Sending idempotency keys in `GET` and `DELETE` requests has no effect
  # and should be avoided, as these requests are idempotent by definition.

  @impl true
  def call(%{method: method} = conn, _) when method in ["POST", "PUT", "PATCH"] do
    case get_req_header(conn, "idempotency-key") do
      [key] -> process_request(conn, key)
      _ -> conn
    end
  end

  def call(conn, _), do: conn

  def process_request(conn, key) do
    case Cachex.get(:idempotency_cache, key) do
      {:ok, nil} ->
        cache_resposnse(conn, key)

      {:ok, record} ->
        send_cached(conn, key, record)

      {atom, message} when atom in [:ignore, :error] ->
        render_error(conn, message)
    end
  end

  defp cache_resposnse(conn, key) do
    register_before_send(conn, fn conn ->
      [request_id] = get_resp_header(conn, "x-request-id")
      content_type = get_content_type(conn)

      record = {request_id, content_type, conn.status, conn.resp_body}
      {:ok, _} = Cachex.put(:idempotency_cache, key, record)

      conn
      |> put_resp_header("idempotency-key", key)
      |> put_resp_header("x-original-request-id", request_id)
    end)
  end

  defp send_cached(conn, key, record) do
    {request_id, content_type, status, body} = record

    conn
    |> put_resp_header("idempotency-key", key)
    |> put_resp_header("idempotent-replayed", "true")
    |> put_resp_header("x-original-request-id", request_id)
    |> put_resp_content_type(content_type)
    |> send_resp(status, body)
    |> halt()
  end

  defp render_error(conn, message) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: message})
    |> halt()
  end

  defp get_content_type(conn) do
    [content_type] = get_resp_header(conn, "content-type")

    if String.contains?(content_type, ";") do
      content_type
      |> String.split(";")
      |> hd()
    else
      content_type
    end
  end
end
