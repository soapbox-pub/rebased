# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.FedSockets.SocketInfoTest do
  use ExUnit.Case

  alias Pleroma.Web.FedSockets
  alias Pleroma.Web.FedSockets.SocketInfo

  describe "uri_for_origin" do
    test "provides the fed_socket URL given the origin information" do
      endpoint = "example.com:4000"
      assert FedSockets.uri_for_origin(endpoint) =~ "ws://"
      assert FedSockets.uri_for_origin(endpoint) =~ endpoint
    end
  end

  describe "origin" do
    test "will provide the origin field given a url" do
      endpoint = "example.com:4000"
      assert SocketInfo.origin("ws://#{endpoint}") == endpoint
      assert SocketInfo.origin("http://#{endpoint}") == endpoint
      assert SocketInfo.origin("https://#{endpoint}") == endpoint
    end

    test "will proide the origin field given a uri" do
      endpoint = "example.com:4000"
      uri = URI.parse("http://#{endpoint}")

      assert SocketInfo.origin(uri) == endpoint
    end
  end

  describe "touch" do
    test "will update the TTL" do
      endpoint = "example.com:4000"
      socket = SocketInfo.build("ws://#{endpoint}")
      Process.sleep(2)
      touched_socket = SocketInfo.touch(socket)

      assert socket.connected_until < touched_socket.connected_until
    end
  end

  describe "expired?" do
    setup do
      start_supervised(
        {Pleroma.Web.FedSockets.Supervisor,
         [
           ping_interval: 8,
           connection_duration: 5,
           rejection_duration: 5,
           fed_socket_rejections: [lazy: true]
         ]}
      )

      :ok
    end

    test "tests if the TTL is exceeded" do
      endpoint = "example.com:4000"
      socket = SocketInfo.build("ws://#{endpoint}")
      refute SocketInfo.expired?(socket)
      Process.sleep(10)

      assert SocketInfo.expired?(socket)
    end
  end

  describe "creating outgoing connection records" do
    test "can be passed a string" do
      assert %{conn_pid: :pid, origin: _origin} = SocketInfo.build("example.com:4000", :pid)
    end

    test "can be passed a URI" do
      uri = URI.parse("http://example.com:4000")
      assert %{conn_pid: :pid, origin: origin} = SocketInfo.build(uri, :pid)
      assert origin =~ "example.com:4000"
    end

    test "will include the port number" do
      assert %{conn_pid: :pid, origin: origin} = SocketInfo.build("http://example.com:4000", :pid)

      assert origin =~ ":4000"
    end

    test "will provide the port if missing" do
      assert %{conn_pid: :pid, origin: "example.com:80"} =
               SocketInfo.build("http://example.com", :pid)

      assert %{conn_pid: :pid, origin: "example.com:443"} =
               SocketInfo.build("https://example.com", :pid)
    end
  end

  describe "creating incoming connection records" do
    test "can be passed a string" do
      assert %{pid: _, origin: _origin} = SocketInfo.build("example.com:4000")
    end

    test "can be passed a URI" do
      uri = URI.parse("example.com:4000")
      assert %{pid: _, origin: _origin} = SocketInfo.build(uri)
    end

    test "will include the port number" do
      assert %{pid: _, origin: origin} = SocketInfo.build("http://example.com:4000")

      assert origin =~ ":4000"
    end

    test "will provide the port if missing" do
      assert %{pid: _, origin: "example.com:80"} = SocketInfo.build("http://example.com")
      assert %{pid: _, origin: "example.com:443"} = SocketInfo.build("https://example.com")
    end
  end
end
