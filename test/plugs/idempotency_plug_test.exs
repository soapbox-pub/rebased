# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.IdempotencyPlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Pleroma.Plugs.IdempotencyPlug
  alias Plug.Conn

  test "returns result from cache" do
    key = "test1"
    orig_request_id = "test1"
    second_request_id = "test2"
    body = "testing"
    status = 200

    :post
    |> conn("/cofe")
    |> put_req_header("idempotency-key", key)
    |> Conn.put_resp_header("x-request-id", orig_request_id)
    |> Conn.put_resp_content_type("application/json")
    |> IdempotencyPlug.call([])
    |> Conn.send_resp(status, body)

    conn =
      :post
      |> conn("/cofe")
      |> put_req_header("idempotency-key", key)
      |> Conn.put_resp_header("x-request-id", second_request_id)
      |> Conn.put_resp_content_type("application/json")
      |> IdempotencyPlug.call([])

    assert_raise Conn.AlreadySentError, fn ->
      Conn.send_resp(conn, :im_a_teapot, "no cofe")
    end

    assert conn.resp_body == body
    assert conn.status == status

    assert [^second_request_id] = Conn.get_resp_header(conn, "x-request-id")
    assert [^orig_request_id] = Conn.get_resp_header(conn, "x-original-request-id")
    assert [^key] = Conn.get_resp_header(conn, "idempotency-key")
    assert ["true"] = Conn.get_resp_header(conn, "idempotent-replayed")
    assert ["application/json; charset=utf-8"] = Conn.get_resp_header(conn, "content-type")
  end

  test "pass conn downstream if the cache not found" do
    key = "test2"
    orig_request_id = "test3"
    body = "testing"
    status = 200

    conn =
      :post
      |> conn("/cofe")
      |> put_req_header("idempotency-key", key)
      |> Conn.put_resp_header("x-request-id", orig_request_id)
      |> Conn.put_resp_content_type("application/json")
      |> IdempotencyPlug.call([])
      |> Conn.send_resp(status, body)

    assert conn.resp_body == body
    assert conn.status == status

    assert [] = Conn.get_resp_header(conn, "idempotent-replayed")
    assert [^key] = Conn.get_resp_header(conn, "idempotency-key")
  end

  test "passes conn downstream if idempotency is not present in headers" do
    orig_request_id = "test4"
    body = "testing"
    status = 200

    conn =
      :post
      |> conn("/cofe")
      |> Conn.put_resp_header("x-request-id", orig_request_id)
      |> Conn.put_resp_content_type("application/json")
      |> IdempotencyPlug.call([])
      |> Conn.send_resp(status, body)

    assert [] = Conn.get_resp_header(conn, "idempotency-key")
  end

  test "doesn't work with GET/DELETE" do
    key = "test3"
    body = "testing"
    status = 200

    conn =
      :get
      |> conn("/cofe")
      |> put_req_header("idempotency-key", key)
      |> IdempotencyPlug.call([])
      |> Conn.send_resp(status, body)

    assert [] = Conn.get_resp_header(conn, "idempotency-key")

    conn =
      :delete
      |> conn("/cofe")
      |> put_req_header("idempotency-key", key)
      |> IdempotencyPlug.call([])
      |> Conn.send_resp(status, body)

    assert [] = Conn.get_resp_header(conn, "idempotency-key")
  end
end
