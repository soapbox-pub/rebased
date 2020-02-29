# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.RateLimiterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Pleroma.Config
  alias Pleroma.Plugs.RateLimiter

  import Pleroma.Factory
  import Pleroma.Tests.Helpers, only: [clear_config: 1, clear_config: 2]

  # Note: each example must work with separate buckets in order to prevent concurrency issues

  clear_config([Pleroma.Web.Endpoint, :http, :ip])
  clear_config(:rate_limit)

  describe "config" do
    @limiter_name :test_init

    clear_config([Pleroma.Plugs.RemoteIp, :enabled])

    test "config is required for plug to work" do
      Config.put([:rate_limit, @limiter_name], {1, 1})
      Config.put([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})

      assert %{limits: {1, 1}, name: :test_init, opts: [name: :test_init]} ==
               [name: @limiter_name]
               |> RateLimiter.init()
               |> RateLimiter.action_settings()

      assert nil ==
               [name: :nonexisting_limiter]
               |> RateLimiter.init()
               |> RateLimiter.action_settings()
    end

    test "it is disabled for localhost" do
      Config.put([:rate_limit, @limiter_name], {1, 1})
      Config.put([Pleroma.Web.Endpoint, :http, :ip], {127, 0, 0, 1})
      Config.put([Pleroma.Plugs.RemoteIp, :enabled], false)

      assert RateLimiter.disabled?() == true
    end

    test "it is disabled for socket" do
      Config.put([:rate_limit, @limiter_name], {1, 1})
      Config.put([Pleroma.Web.Endpoint, :http, :ip], {:local, "/path/to/pleroma.sock"})
      Config.put([Pleroma.Plugs.RemoteIp, :enabled], false)

      assert RateLimiter.disabled?() == true
    end

    test "it is enabled for socket when remote ip is enabled" do
      Config.put([:rate_limit, @limiter_name], {1, 1})
      Config.put([Pleroma.Web.Endpoint, :http, :ip], {:local, "/path/to/pleroma.sock"})
      Config.put([Pleroma.Plugs.RemoteIp, :enabled], true)

      assert RateLimiter.disabled?() == false
    end

    test "it restricts based on config values" do
      limiter_name = :test_plug_opts
      scale = 80
      limit = 5

      Config.put([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})
      Config.put([:rate_limit, limiter_name], {scale, limit})

      plug_opts = RateLimiter.init(name: limiter_name)
      conn = conn(:get, "/")

      for i <- 1..5 do
        conn = RateLimiter.call(conn, plug_opts)
        assert {^i, _} = RateLimiter.inspect_bucket(conn, limiter_name, plug_opts)
        Process.sleep(10)
      end

      conn = RateLimiter.call(conn, plug_opts)
      assert %{"error" => "Throttled"} = Phoenix.ConnTest.json_response(conn, :too_many_requests)
      assert conn.halted

      Process.sleep(50)

      conn = conn(:get, "/")

      conn = RateLimiter.call(conn, plug_opts)
      assert {1, 4} = RateLimiter.inspect_bucket(conn, limiter_name, plug_opts)

      refute conn.status == Plug.Conn.Status.code(:too_many_requests)
      refute conn.resp_body
      refute conn.halted
    end
  end

  describe "options" do
    test "`bucket_name` option overrides default bucket name" do
      limiter_name = :test_bucket_name

      Config.put([:rate_limit, limiter_name], {1000, 5})
      Config.put([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})

      base_bucket_name = "#{limiter_name}:group1"
      plug_opts = RateLimiter.init(name: limiter_name, bucket_name: base_bucket_name)

      conn = conn(:get, "/")

      RateLimiter.call(conn, plug_opts)
      assert {1, 4} = RateLimiter.inspect_bucket(conn, base_bucket_name, plug_opts)
      assert {:error, :not_found} = RateLimiter.inspect_bucket(conn, limiter_name, plug_opts)
    end

    test "`params` option allows different queries to be tracked independently" do
      limiter_name = :test_params
      Config.put([:rate_limit, limiter_name], {1000, 5})
      Config.put([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})

      plug_opts = RateLimiter.init(name: limiter_name, params: ["id"])

      conn = conn(:get, "/?id=1")
      conn = Plug.Conn.fetch_query_params(conn)
      conn_2 = conn(:get, "/?id=2")

      RateLimiter.call(conn, plug_opts)
      assert {1, 4} = RateLimiter.inspect_bucket(conn, limiter_name, plug_opts)
      assert {0, 5} = RateLimiter.inspect_bucket(conn_2, limiter_name, plug_opts)
    end

    test "it supports combination of options modifying bucket name" do
      limiter_name = :test_options_combo
      Config.put([:rate_limit, limiter_name], {1000, 5})
      Config.put([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})

      base_bucket_name = "#{limiter_name}:group1"

      plug_opts =
        RateLimiter.init(name: limiter_name, bucket_name: base_bucket_name, params: ["id"])

      id = "100"

      conn = conn(:get, "/?id=#{id}")
      conn = Plug.Conn.fetch_query_params(conn)
      conn_2 = conn(:get, "/?id=#{101}")

      RateLimiter.call(conn, plug_opts)
      assert {1, 4} = RateLimiter.inspect_bucket(conn, base_bucket_name, plug_opts)
      assert {0, 5} = RateLimiter.inspect_bucket(conn_2, base_bucket_name, plug_opts)
    end
  end

  describe "unauthenticated users" do
    test "are restricted based on remote IP" do
      limiter_name = :test_unauthenticated
      Config.put([:rate_limit, limiter_name], [{1000, 5}, {1, 10}])
      Config.put([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})

      plug_opts = RateLimiter.init(name: limiter_name)

      conn = %{conn(:get, "/") | remote_ip: {127, 0, 0, 2}}
      conn_2 = %{conn(:get, "/") | remote_ip: {127, 0, 0, 3}}

      for i <- 1..5 do
        conn = RateLimiter.call(conn, plug_opts)
        assert {^i, _} = RateLimiter.inspect_bucket(conn, limiter_name, plug_opts)
        refute conn.halted
      end

      conn = RateLimiter.call(conn, plug_opts)

      assert %{"error" => "Throttled"} = Phoenix.ConnTest.json_response(conn, :too_many_requests)
      assert conn.halted

      conn_2 = RateLimiter.call(conn_2, plug_opts)
      assert {1, 4} = RateLimiter.inspect_bucket(conn_2, limiter_name, plug_opts)

      refute conn_2.status == Plug.Conn.Status.code(:too_many_requests)
      refute conn_2.resp_body
      refute conn_2.halted
    end
  end

  describe "authenticated users" do
    setup do
      Ecto.Adapters.SQL.Sandbox.checkout(Pleroma.Repo)

      :ok
    end

    test "can have limits separate from unauthenticated connections" do
      limiter_name = :test_authenticated1

      scale = 50
      limit = 5
      Config.put([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})
      Config.put([:rate_limit, limiter_name], [{1000, 1}, {scale, limit}])

      plug_opts = RateLimiter.init(name: limiter_name)

      user = insert(:user)
      conn = conn(:get, "/") |> assign(:user, user)

      for i <- 1..5 do
        conn = RateLimiter.call(conn, plug_opts)
        assert {^i, _} = RateLimiter.inspect_bucket(conn, limiter_name, plug_opts)
        refute conn.halted
      end

      conn = RateLimiter.call(conn, plug_opts)

      assert %{"error" => "Throttled"} = Phoenix.ConnTest.json_response(conn, :too_many_requests)
      assert conn.halted
    end

    test "different users are counted independently" do
      limiter_name = :test_authenticated2
      Config.put([:rate_limit, limiter_name], [{1, 10}, {1000, 5}])
      Config.put([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})

      plug_opts = RateLimiter.init(name: limiter_name)

      user = insert(:user)
      conn = conn(:get, "/") |> assign(:user, user)

      user_2 = insert(:user)
      conn_2 = conn(:get, "/") |> assign(:user, user_2)

      for i <- 1..5 do
        conn = RateLimiter.call(conn, plug_opts)
        assert {^i, _} = RateLimiter.inspect_bucket(conn, limiter_name, plug_opts)
      end

      conn = RateLimiter.call(conn, plug_opts)
      assert %{"error" => "Throttled"} = Phoenix.ConnTest.json_response(conn, :too_many_requests)
      assert conn.halted

      conn_2 = RateLimiter.call(conn_2, plug_opts)
      assert {1, 4} = RateLimiter.inspect_bucket(conn_2, limiter_name, plug_opts)
      refute conn_2.status == Plug.Conn.Status.code(:too_many_requests)
      refute conn_2.resp_body
      refute conn_2.halted
    end
  end
end
