# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.Adapter.GunTest do
  use ExUnit.Case, async: true
  use Pleroma.Tests.Helpers
  import ExUnit.CaptureLog
  alias Pleroma.Config
  alias Pleroma.HTTP.Adapter.Gun
  alias Pleroma.Pool.Connections

  setup_all do
    {:ok, _} = Registry.start_link(keys: :unique, name: Pleroma.Gun.API.Mock)
    :ok
  end

  describe "options/1" do
    clear_config([:http, :adapter]) do
      Config.put([:http, :adapter], a: 1, b: 2)
    end

    test "https url with default port" do
      uri = URI.parse("https://example.com")

      opts = Gun.options(uri)
      assert opts[:certificates_verification]
      tls_opts = opts[:tls_opts]
      assert tls_opts[:verify] == :verify_peer
      assert tls_opts[:depth] == 20
      assert tls_opts[:reuse_sessions] == false

      assert tls_opts[:verify_fun] ==
               {&:ssl_verify_hostname.verify_fun/3, [check_hostname: 'example.com']}

      assert File.exists?(tls_opts[:cacertfile])

      assert opts[:original] == "example.com:443"
    end

    test "https ipv4 with default port" do
      uri = URI.parse("https://127.0.0.1")

      opts = Gun.options(uri)

      assert opts[:tls_opts][:verify_fun] ==
               {&:ssl_verify_hostname.verify_fun/3, [check_hostname: '127.0.0.1']}

      assert opts[:original] == "127.0.0.1:443"
    end

    test "https ipv6 with default port" do
      uri = URI.parse("https://[2a03:2880:f10c:83:face:b00c:0:25de]")

      opts = Gun.options(uri)

      assert opts[:tls_opts][:verify_fun] ==
               {&:ssl_verify_hostname.verify_fun/3,
                [check_hostname: '2a03:2880:f10c:83:face:b00c:0:25de']}

      assert opts[:original] == "2a03:2880:f10c:83:face:b00c:0:25de:443"
    end

    test "https url with non standart port" do
      uri = URI.parse("https://example.com:115")

      opts = Gun.options(uri)

      assert opts[:certificates_verification]
      assert opts[:transport] == :tls
    end

    test "receive conn by default" do
      uri = URI.parse("http://another-domain.com")
      :ok = Connections.open_conn(uri, :gun_connections)

      received_opts = Gun.options(uri)
      assert received_opts[:close_conn] == false
      assert is_pid(received_opts[:conn])
    end

    test "don't receive conn if receive_conn is false" do
      uri = URI.parse("http://another-domain2.com")
      :ok = Connections.open_conn(uri, :gun_connections)

      opts = [receive_conn: false]
      received_opts = Gun.options(opts, uri)
      assert received_opts[:close_conn] == nil
      assert received_opts[:conn] == nil
    end

    test "get conn on next request" do
      level = Application.get_env(:logger, :level)
      Logger.configure(level: :debug)
      on_exit(fn -> Logger.configure(level: level) end)
      uri = URI.parse("http://some-domain2.com")

      assert capture_log(fn ->
               opts = Gun.options(uri)

               assert opts[:conn] == nil
               assert opts[:close_conn] == nil
             end) =~
               "Gun connections pool checkin was not successful. Trying to open conn for next request."

      opts = Gun.options(uri)

      assert is_pid(opts[:conn])
      assert opts[:close_conn] == false
    end

    test "merges with defaul http adapter config" do
      defaults = Gun.options(URI.parse("https://example.com"))
      assert Keyword.has_key?(defaults, :a)
      assert Keyword.has_key?(defaults, :b)
    end

    test "default ssl adapter opts with connection" do
      uri = URI.parse("https://some-domain.com")

      :ok = Connections.open_conn(uri, :gun_connections)

      opts = Gun.options(uri)

      assert opts[:certificates_verification]
      tls_opts = opts[:tls_opts]
      assert tls_opts[:verify] == :verify_peer
      assert tls_opts[:depth] == 20
      assert tls_opts[:reuse_sessions] == false

      assert opts[:original] == "some-domain.com:443"
      assert opts[:close_conn] == false
      assert is_pid(opts[:conn])
    end

    test "parses string proxy host & port" do
      proxy = Config.get([:http, :proxy_url])
      Config.put([:http, :proxy_url], "localhost:8123")
      on_exit(fn -> Config.put([:http, :proxy_url], proxy) end)

      uri = URI.parse("https://some-domain.com")
      opts = Gun.options([receive_conn: false], uri)
      assert opts[:proxy] == {'localhost', 8123}
    end

    test "parses tuple proxy scheme host and port" do
      proxy = Config.get([:http, :proxy_url])
      Config.put([:http, :proxy_url], {:socks, 'localhost', 1234})
      on_exit(fn -> Config.put([:http, :proxy_url], proxy) end)

      uri = URI.parse("https://some-domain.com")
      opts = Gun.options([receive_conn: false], uri)
      assert opts[:proxy] == {:socks, 'localhost', 1234}
    end

    test "passed opts have more weight than defaults" do
      proxy = Config.get([:http, :proxy_url])
      Config.put([:http, :proxy_url], {:socks5, 'localhost', 1234})
      on_exit(fn -> Config.put([:http, :proxy_url], proxy) end)
      uri = URI.parse("https://some-domain.com")
      opts = Gun.options([receive_conn: false, proxy: {'example.com', 4321}], uri)

      assert opts[:proxy] == {'example.com', 4321}
    end
  end

  describe "after_request/1" do
    test "body_as not chunks" do
      uri = URI.parse("http://some-domain.com")
      :ok = Connections.open_conn(uri, :gun_connections)
      opts = Gun.options(uri)
      :ok = Gun.after_request(opts)
      conn = opts[:conn]

      assert %Connections{
               conns: %{
                 "http:some-domain.com:80" => %Pleroma.Gun.Conn{
                   conn: ^conn,
                   conn_state: :idle,
                   used_by: []
                 }
               }
             } = Connections.get_state(:gun_connections)
    end

    test "body_as chunks" do
      uri = URI.parse("http://some-domain.com")
      :ok = Connections.open_conn(uri, :gun_connections)
      opts = Gun.options([body_as: :chunks], uri)
      :ok = Gun.after_request(opts)
      conn = opts[:conn]
      self = self()

      assert %Connections{
               conns: %{
                 "http:some-domain.com:80" => %Pleroma.Gun.Conn{
                   conn: ^conn,
                   conn_state: :active,
                   used_by: [{^self, _}]
                 }
               }
             } = Connections.get_state(:gun_connections)
    end

    test "with no connection" do
      uri = URI.parse("http://uniq-domain.com")

      :ok = Connections.open_conn(uri, :gun_connections)

      opts = Gun.options([body_as: :chunks], uri)
      conn = opts[:conn]
      opts = Keyword.delete(opts, :conn)
      self = self()

      :ok = Gun.after_request(opts)

      assert %Connections{
               conns: %{
                 "http:uniq-domain.com:80" => %Pleroma.Gun.Conn{
                   conn: ^conn,
                   conn_state: :active,
                   used_by: [{^self, _}]
                 }
               }
             } = Connections.get_state(:gun_connections)
    end

    test "with ipv4" do
      uri = URI.parse("http://127.0.0.1")
      :ok = Connections.open_conn(uri, :gun_connections)
      opts = Gun.options(uri)
      send(:gun_connections, {:gun_up, opts[:conn], :http})
      :ok = Gun.after_request(opts)
      conn = opts[:conn]

      assert %Connections{
               conns: %{
                 "http:127.0.0.1:80" => %Pleroma.Gun.Conn{
                   conn: ^conn,
                   conn_state: :idle,
                   used_by: []
                 }
               }
             } = Connections.get_state(:gun_connections)
    end

    test "with ipv6" do
      uri = URI.parse("http://[2a03:2880:f10c:83:face:b00c:0:25de]")
      :ok = Connections.open_conn(uri, :gun_connections)
      opts = Gun.options(uri)
      send(:gun_connections, {:gun_up, opts[:conn], :http})
      :ok = Gun.after_request(opts)
      conn = opts[:conn]

      assert %Connections{
               conns: %{
                 "http:2a03:2880:f10c:83:face:b00c:0:25de:80" => %Pleroma.Gun.Conn{
                   conn: ^conn,
                   conn_state: :idle,
                   used_by: []
                 }
               }
             } = Connections.get_state(:gun_connections)
    end
  end
end
