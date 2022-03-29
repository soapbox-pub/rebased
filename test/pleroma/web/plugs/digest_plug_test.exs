# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.DigestPlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  test "digest algorithm is taken from digest header" do
    body = "{\"hello\": \"world\"}"
    digest = "X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE="

    {:ok, ^body, conn} =
      :get
      |> conn("/", body)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("digest", "sha-256=" <> digest)
      |> Pleroma.Web.Plugs.DigestPlug.read_body([])

    assert conn.assigns[:digest] == "sha-256=" <> digest

    {:ok, ^body, conn} =
      :get
      |> conn("/", body)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("digest", "SHA-256=" <> digest)
      |> Pleroma.Web.Plugs.DigestPlug.read_body([])

    assert conn.assigns[:digest] == "SHA-256=" <> digest
  end

  test "error if digest algorithm is invalid" do
    body = "{\"hello\": \"world\"}"
    digest = "X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE="

    assert_raise ArgumentError, "invalid value for digest algorithm, got: MD5", fn ->
      :get
      |> conn("/", body)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("digest", "MD5=" <> digest)
      |> Pleroma.Web.Plugs.DigestPlug.read_body([])
    end

    assert_raise ArgumentError, "invalid value for digest algorithm, got: md5", fn ->
      :get
      |> conn("/", body)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("digest", "md5=" <> digest)
      |> Pleroma.Web.Plugs.DigestPlug.read_body([])
    end
  end
end
