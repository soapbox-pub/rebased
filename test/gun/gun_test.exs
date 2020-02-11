# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.GunTest do
  use ExUnit.Case
  alias Pleroma.Gun

  @moduletag :integration

  test "opens connection and receive response" do
    {:ok, conn} = Gun.open('httpbin.org', 443)
    assert is_pid(conn)
    {:ok, _protocol} = Gun.await_up(conn)
    ref = :gun.get(conn, '/get?a=b&c=d')
    assert is_reference(ref)

    assert {:response, :nofin, 200, _} = Gun.await(conn, ref)
    assert json = receive_response(conn, ref)

    assert %{"args" => %{"a" => "b", "c" => "d"}} = Jason.decode!(json)
  end

  defp receive_response(conn, ref, acc \\ "") do
    case Gun.await(conn, ref) do
      {:data, :nofin, body} ->
        receive_response(conn, ref, acc <> body)

      {:data, :fin, body} ->
        acc <> body
    end
  end
end
