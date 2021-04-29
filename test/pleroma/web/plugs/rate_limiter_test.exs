# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.RateLimiterTest do
  use Pleroma.Web.ConnCase

  alias Phoenix.ConnTest
  alias Pleroma.Web.Plugs.RateLimiter
  alias Plug.Conn

  import Pleroma.Factory
  import Pleroma.Tests.Helpers, only: [clear_config: 1, clear_config: 2]

  # Note: each example must work with separate buckets in order to prevent concurrency issues
  setup do: clear_config([Pleroma.Web.Endpoint, :http, :ip])
  setup do: clear_config(:rate_limit)

  describe "config" do
    @limiter_name :test_init
    setup do: clear_config([Pleroma.Web.Plugs.RemoteIp, :enabled])

    test "config is required for plug to work" do
      clear_config([:rate_limit, @limiter_name], {1, 1})
      clear_config([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})

      assert %{limits: {1, 1}, name: :test_init, opts: [name: :test_init]} ==
               [name: @limiter_name]
               |> RateLimiter.init()
               |> RateLimiter.action_settings()

      assert nil ==
               [name: :nonexisting_limiter]
               |> RateLimiter.init()
               |> RateLimiter.action_settings()
    end
  end

  test "it is disabled if it remote ip plug is enabled but no remote ip is found" do
    assert RateLimiter.disabled?(Conn.assign(build_conn(), :remote_ip_found, false))
  end

  test "it is enabled if remote ip found" do
    refute RateLimiter.disabled?(Conn.assign(build_conn(), :remote_ip_found, true))
  end

  test "it is enabled if remote_ip_found flag doesn't exist" do
    refute RateLimiter.disabled?(build_conn())
  end

  test "it restricts based on config values" do
    limiter_name = :test_plug_opts
    scale = 80
    limit = 5

    clear_config([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})
    clear_config([:rate_limit, limiter_name], {scale, limit})

    plug_opts = RateLimiter.init(name: limiter_name)
    conn = build_conn(:get, "/")

    for i <- 1..5 do
      conn = RateLimiter.call(conn, plug_opts)
      assert {^i, _} = RateLimiter.inspect_bucket(conn, limiter_name, plug_opts)
      Process.sleep(10)
    end

    conn = RateLimiter.call(conn, plug_opts)
    assert %{"error" => "Throttled"} = ConnTest.json_response(conn, :too_many_requests)
    assert conn.halted

    Process.sleep(50)

    conn = build_conn(:get, "/")

    conn = RateLimiter.call(conn, plug_opts)
    assert {1, 4} = RateLimiter.inspect_bucket(conn, limiter_name, plug_opts)

    refute conn.status == Conn.Status.code(:too_many_requests)
    refute conn.resp_body
    refute conn.halted
  end

  describe "options" do
    test "`bucket_name` option overrides default bucket name" do
      limiter_name = :test_bucket_name

      clear_config([:rate_limit, limiter_name], {1000, 5})
      clear_config([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})

      base_bucket_name = "#{limiter_name}:group1"
      plug_opts = RateLimiter.init(name: limiter_name, bucket_name: base_bucket_name)

      conn = build_conn(:get, "/")

      RateLimiter.call(conn, plug_opts)
      assert {1, 4} = RateLimiter.inspect_bucket(conn, base_bucket_name, plug_opts)
      assert {:error, :not_found} = RateLimiter.inspect_bucket(conn, limiter_name, plug_opts)
    end

    test "`params` option allows different queries to be tracked independently" do
      limiter_name = :test_params
      clear_config([:rate_limit, limiter_name], {1000, 5})
      clear_config([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})

      plug_opts = RateLimiter.init(name: limiter_name, params: ["id"])

      conn = build_conn(:get, "/?id=1")
      conn = Conn.fetch_query_params(conn)
      conn_2 = build_conn(:get, "/?id=2")

      RateLimiter.call(conn, plug_opts)
      assert {1, 4} = RateLimiter.inspect_bucket(conn, limiter_name, plug_opts)
      assert {0, 5} = RateLimiter.inspect_bucket(conn_2, limiter_name, plug_opts)
    end

    test "it supports combination of options modifying bucket name" do
      limiter_name = :test_options_combo
      clear_config([:rate_limit, limiter_name], {1000, 5})
      clear_config([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})

      base_bucket_name = "#{limiter_name}:group1"

      plug_opts =
        RateLimiter.init(name: limiter_name, bucket_name: base_bucket_name, params: ["id"])

      id = "100"

      conn = build_conn(:get, "/?id=#{id}")
      conn = Conn.fetch_query_params(conn)
      conn_2 = build_conn(:get, "/?id=#{101}")

      RateLimiter.call(conn, plug_opts)
      assert {1, 4} = RateLimiter.inspect_bucket(conn, base_bucket_name, plug_opts)
      assert {0, 5} = RateLimiter.inspect_bucket(conn_2, base_bucket_name, plug_opts)
    end
  end

  describe "unauthenticated users" do
    test "are restricted based on remote IP" do
      limiter_name = :test_unauthenticated
      clear_config([:rate_limit, limiter_name], [{1000, 5}, {1, 10}])
      clear_config([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})

      plug_opts = RateLimiter.init(name: limiter_name)

      conn = %{build_conn(:get, "/") | remote_ip: {127, 0, 0, 2}}
      conn_2 = %{build_conn(:get, "/") | remote_ip: {127, 0, 0, 3}}

      for i <- 1..5 do
        conn = RateLimiter.call(conn, plug_opts)
        assert {^i, _} = RateLimiter.inspect_bucket(conn, limiter_name, plug_opts)
        refute conn.halted
      end

      conn = RateLimiter.call(conn, plug_opts)

      assert %{"error" => "Throttled"} = ConnTest.json_response(conn, :too_many_requests)
      assert conn.halted

      conn_2 = RateLimiter.call(conn_2, plug_opts)
      assert {1, 4} = RateLimiter.inspect_bucket(conn_2, limiter_name, plug_opts)

      refute conn_2.status == Conn.Status.code(:too_many_requests)
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
      clear_config([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})
      clear_config([:rate_limit, limiter_name], [{1000, 1}, {scale, limit}])

      plug_opts = RateLimiter.init(name: limiter_name)

      user = insert(:user)
      conn = build_conn(:get, "/") |> assign(:user, user)

      for i <- 1..5 do
        conn = RateLimiter.call(conn, plug_opts)
        assert {^i, _} = RateLimiter.inspect_bucket(conn, limiter_name, plug_opts)
        refute conn.halted
      end

      conn = RateLimiter.call(conn, plug_opts)

      assert %{"error" => "Throttled"} = ConnTest.json_response(conn, :too_many_requests)
      assert conn.halted
    end

    test "different users are counted independently" do
      limiter_name = :test_authenticated2
      clear_config([:rate_limit, limiter_name], [{1, 10}, {1000, 5}])
      clear_config([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})

      plug_opts = RateLimiter.init(name: limiter_name)

      user = insert(:user)
      conn = build_conn(:get, "/") |> assign(:user, user)

      user_2 = insert(:user)
      conn_2 = build_conn(:get, "/") |> assign(:user, user_2)

      for i <- 1..5 do
        conn = RateLimiter.call(conn, plug_opts)
        assert {^i, _} = RateLimiter.inspect_bucket(conn, limiter_name, plug_opts)
      end

      conn = RateLimiter.call(conn, plug_opts)
      assert %{"error" => "Throttled"} = ConnTest.json_response(conn, :too_many_requests)
      assert conn.halted

      conn_2 = RateLimiter.call(conn_2, plug_opts)
      assert {1, 4} = RateLimiter.inspect_bucket(conn_2, limiter_name, plug_opts)
      refute conn_2.status == Conn.Status.code(:too_many_requests)
      refute conn_2.resp_body
      refute conn_2.halted
    end
  end

  test "doesn't crash due to a race condition when multiple requests are made at the same time and the bucket is not yet initialized" do
    limiter_name = :test_race_condition
    clear_config([:rate_limit, limiter_name], {1000, 5})
    clear_config([Pleroma.Web.Endpoint, :http, :ip], {8, 8, 8, 8})

    opts = RateLimiter.init(name: limiter_name)

    conn = build_conn(:get, "/")
    conn_2 = build_conn(:get, "/")

    %Task{pid: pid1} =
      task1 =
      Task.async(fn ->
        receive do
          :process2_up ->
            RateLimiter.call(conn, opts)
        end
      end)

    task2 =
      Task.async(fn ->
        send(pid1, :process2_up)
        RateLimiter.call(conn_2, opts)
      end)

    Task.await(task1)
    Task.await(task2)

    refute {:err, :not_found} == RateLimiter.inspect_bucket(conn, limiter_name, opts)
  end
end
