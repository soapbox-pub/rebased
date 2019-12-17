# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.RateLimiterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Pleroma.Plugs.RateLimiter

  import Pleroma.Factory

  # Note: each example must work with separate buckets in order to prevent concurrency issues

  describe "config" do
    test "config is required for plug to work" do
      limiter_name = :test_init
      Pleroma.Config.put([:rate_limit, limiter_name], {1, 1})
      Pleroma.Config.put([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})

      assert %{limits: {1, 1}, name: :test_init, opts: [name: :test_init]} ==
               RateLimiter.init(name: limiter_name)

      assert nil == RateLimiter.init(name: :foo)
    end

    test "it is disabled for localhost" do
      limiter_name = :test_init
      Pleroma.Config.put([:rate_limit, limiter_name], {1, 1})
      Pleroma.Config.put([Pleroma.Web.Endpoint, :http, :ip], {127, 0, 0, 1})
      Pleroma.Config.put([Pleroma.Plugs.RemoteIp, :enabled], false)

      assert RateLimiter.disabled?() == true
    end

    test "it is disabled for socket" do
      limiter_name = :test_init
      Pleroma.Config.put([:rate_limit, limiter_name], {1, 1})
      Pleroma.Config.put([Pleroma.Web.Endpoint, :http, :ip], {:local, "/path/to/pleroma.sock"})
      Pleroma.Config.put([Pleroma.Plugs.RemoteIp, :enabled], false)

      assert RateLimiter.disabled?() == true
    end

    test "it is enabled for socket when remote ip is enabled" do
      limiter_name = :test_init
      Pleroma.Config.put([:rate_limit, limiter_name], {1, 1})
      Pleroma.Config.put([Pleroma.Web.Endpoint, :http, :ip], {:local, "/path/to/pleroma.sock"})
      Pleroma.Config.put([Pleroma.Plugs.RemoteIp, :enabled], true)

      assert RateLimiter.disabled?() == false
    end

    test "it restricts based on config values" do
      limiter_name = :test_opts
      scale = 80
      limit = 5

      Pleroma.Config.put([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})
      Pleroma.Config.put([:rate_limit, limiter_name], {scale, limit})

      opts = RateLimiter.init(name: limiter_name)
      conn = conn(:get, "/")

      for i <- 1..5 do
        conn = RateLimiter.call(conn, opts)
        assert {^i, _} = RateLimiter.inspect_bucket(conn, limiter_name, opts)
        Process.sleep(10)
      end

      conn = RateLimiter.call(conn, opts)
      assert %{"error" => "Throttled"} = Phoenix.ConnTest.json_response(conn, :too_many_requests)
      assert conn.halted

      Process.sleep(50)

      conn = conn(:get, "/")

      conn = RateLimiter.call(conn, opts)
      assert {1, 4} = RateLimiter.inspect_bucket(conn, limiter_name, opts)

      refute conn.status == Plug.Conn.Status.code(:too_many_requests)
      refute conn.resp_body
      refute conn.halted
    end
  end

  describe "options" do
    test "`bucket_name` option overrides default bucket name" do
      limiter_name = :test_bucket_name

      Pleroma.Config.put([:rate_limit, limiter_name], {1000, 5})
      Pleroma.Config.put([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})

      base_bucket_name = "#{limiter_name}:group1"
      opts = RateLimiter.init(name: limiter_name, bucket_name: base_bucket_name)

      conn = conn(:get, "/")

      RateLimiter.call(conn, opts)
      assert {1, 4} = RateLimiter.inspect_bucket(conn, base_bucket_name, opts)
      assert {:err, :not_found} = RateLimiter.inspect_bucket(conn, limiter_name, opts)
    end

    test "`params` option allows different queries to be tracked independently" do
      limiter_name = :test_params
      Pleroma.Config.put([:rate_limit, limiter_name], {1000, 5})
      Pleroma.Config.put([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})

      opts = RateLimiter.init(name: limiter_name, params: ["id"])

      conn = conn(:get, "/?id=1")
      conn = Plug.Conn.fetch_query_params(conn)
      conn_2 = conn(:get, "/?id=2")

      RateLimiter.call(conn, opts)
      assert {1, 4} = RateLimiter.inspect_bucket(conn, limiter_name, opts)
      assert {0, 5} = RateLimiter.inspect_bucket(conn_2, limiter_name, opts)
    end

    test "it supports combination of options modifying bucket name" do
      limiter_name = :test_options_combo
      Pleroma.Config.put([:rate_limit, limiter_name], {1000, 5})
      Pleroma.Config.put([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})

      base_bucket_name = "#{limiter_name}:group1"
      opts = RateLimiter.init(name: limiter_name, bucket_name: base_bucket_name, params: ["id"])
      id = "100"

      conn = conn(:get, "/?id=#{id}")
      conn = Plug.Conn.fetch_query_params(conn)
      conn_2 = conn(:get, "/?id=#{101}")

      RateLimiter.call(conn, opts)
      assert {1, 4} = RateLimiter.inspect_bucket(conn, base_bucket_name, opts)
      assert {0, 5} = RateLimiter.inspect_bucket(conn_2, base_bucket_name, opts)
    end
  end

  describe "unauthenticated users" do
    test "are restricted based on remote IP" do
      limiter_name = :test_unauthenticated
      Pleroma.Config.put([:rate_limit, limiter_name], [{1000, 5}, {1, 10}])
      Pleroma.Config.put([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})

      opts = RateLimiter.init(name: limiter_name)

      conn = %{conn(:get, "/") | remote_ip: {127, 0, 0, 2}}
      conn_2 = %{conn(:get, "/") | remote_ip: {127, 0, 0, 3}}

      for i <- 1..5 do
        conn = RateLimiter.call(conn, opts)
        assert {^i, _} = RateLimiter.inspect_bucket(conn, limiter_name, opts)
        refute conn.halted
      end

      conn = RateLimiter.call(conn, opts)

      assert %{"error" => "Throttled"} = Phoenix.ConnTest.json_response(conn, :too_many_requests)
      assert conn.halted

      conn_2 = RateLimiter.call(conn_2, opts)
      assert {1, 4} = RateLimiter.inspect_bucket(conn_2, limiter_name, opts)

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

    test "can have limits seperate from unauthenticated connections" do
      limiter_name = :test_authenticated

      scale = 50
      limit = 5
      Pleroma.Config.put([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})
      Pleroma.Config.put([:rate_limit, limiter_name], [{1000, 1}, {scale, limit}])

      opts = RateLimiter.init(name: limiter_name)

      user = insert(:user)
      conn = conn(:get, "/") |> assign(:user, user)

      for i <- 1..5 do
        conn = RateLimiter.call(conn, opts)
        assert {^i, _} = RateLimiter.inspect_bucket(conn, limiter_name, opts)
        refute conn.halted
      end

      conn = RateLimiter.call(conn, opts)

      assert %{"error" => "Throttled"} = Phoenix.ConnTest.json_response(conn, :too_many_requests)
      assert conn.halted
    end

    test "diffrerent users are counted independently" do
      limiter_name = :test_authenticated
      Pleroma.Config.put([:rate_limit, limiter_name], [{1, 10}, {1000, 5}])
      Pleroma.Config.put([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})

      opts = RateLimiter.init(name: limiter_name)

      user = insert(:user)
      conn = conn(:get, "/") |> assign(:user, user)

      user_2 = insert(:user)
      conn_2 = conn(:get, "/") |> assign(:user, user_2)

      for i <- 1..5 do
        conn = RateLimiter.call(conn, opts)
        assert {^i, _} = RateLimiter.inspect_bucket(conn, limiter_name, opts)
      end

      conn = RateLimiter.call(conn, opts)
      assert %{"error" => "Throttled"} = Phoenix.ConnTest.json_response(conn, :too_many_requests)
      assert conn.halted

      conn_2 = RateLimiter.call(conn_2, opts)
      assert {1, 4} = RateLimiter.inspect_bucket(conn_2, limiter_name, opts)
      refute conn_2.status == Plug.Conn.Status.code(:too_many_requests)
      refute conn_2.resp_body
      refute conn_2.halted
    end
  end
end
