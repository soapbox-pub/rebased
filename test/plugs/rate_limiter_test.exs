# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.RateLimiterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Pleroma.Plugs.RateLimiter

  import Pleroma.Factory

  # Note: each example must work with separate buckets in order to prevent concurrency issues

  test "init/1" do
    limiter_name = :test_init
    Pleroma.Config.put([:rate_limit, limiter_name], {1, 1})

    assert {limiter_name, {1, 1}, []} == RateLimiter.init(limiter_name)
    assert nil == RateLimiter.init(:foo)
  end

  test "ip/1" do
    assert "127.0.0.1" == RateLimiter.ip(%{remote_ip: {127, 0, 0, 1}})
  end

  test "it restricts by opts" do
    limiter_name = :test_opts
    scale = 1000
    limit = 5

    Pleroma.Config.put([:rate_limit, limiter_name], {scale, limit})

    opts = RateLimiter.init(limiter_name)
    conn = conn(:get, "/")
    bucket_name = "#{limiter_name}:#{RateLimiter.ip(conn)}"

    conn = RateLimiter.call(conn, opts)
    assert {1, 4, _, _, _} = ExRated.inspect_bucket(bucket_name, scale, limit)

    conn = RateLimiter.call(conn, opts)
    assert {2, 3, _, _, _} = ExRated.inspect_bucket(bucket_name, scale, limit)

    conn = RateLimiter.call(conn, opts)
    assert {3, 2, _, _, _} = ExRated.inspect_bucket(bucket_name, scale, limit)

    conn = RateLimiter.call(conn, opts)
    assert {4, 1, _, _, _} = ExRated.inspect_bucket(bucket_name, scale, limit)

    conn = RateLimiter.call(conn, opts)
    assert {5, 0, to_reset, _, _} = ExRated.inspect_bucket(bucket_name, scale, limit)

    conn = RateLimiter.call(conn, opts)

    assert %{"error" => "Throttled"} = Phoenix.ConnTest.json_response(conn, :too_many_requests)
    assert conn.halted

    Process.sleep(to_reset)

    conn = conn(:get, "/")

    conn = RateLimiter.call(conn, opts)
    assert {1, 4, _, _, _} = ExRated.inspect_bucket(bucket_name, scale, limit)

    refute conn.status == Plug.Conn.Status.code(:too_many_requests)
    refute conn.resp_body
    refute conn.halted
  end

  test "`bucket_name` option overrides default bucket name" do
    limiter_name = :test_bucket_name
    scale = 1000
    limit = 5

    Pleroma.Config.put([:rate_limit, limiter_name], {scale, limit})
    base_bucket_name = "#{limiter_name}:group1"
    opts = RateLimiter.init({limiter_name, bucket_name: base_bucket_name})

    conn = conn(:get, "/")
    default_bucket_name = "#{limiter_name}:#{RateLimiter.ip(conn)}"
    customized_bucket_name = "#{base_bucket_name}:#{RateLimiter.ip(conn)}"

    RateLimiter.call(conn, opts)
    assert {1, 4, _, _, _} = ExRated.inspect_bucket(customized_bucket_name, scale, limit)
    assert {0, 5, _, _, _} = ExRated.inspect_bucket(default_bucket_name, scale, limit)
  end

  test "`params` option appends specified params' values to bucket name" do
    limiter_name = :test_params
    scale = 1000
    limit = 5

    Pleroma.Config.put([:rate_limit, limiter_name], {scale, limit})
    opts = RateLimiter.init({limiter_name, params: ["id"]})
    id = "1"

    conn = conn(:get, "/?id=#{id}")
    conn = Plug.Conn.fetch_query_params(conn)

    default_bucket_name = "#{limiter_name}:#{RateLimiter.ip(conn)}"
    parametrized_bucket_name = "#{limiter_name}:#{id}:#{RateLimiter.ip(conn)}"

    RateLimiter.call(conn, opts)
    assert {1, 4, _, _, _} = ExRated.inspect_bucket(parametrized_bucket_name, scale, limit)
    assert {0, 5, _, _, _} = ExRated.inspect_bucket(default_bucket_name, scale, limit)
  end

  test "it supports combination of options modifying bucket name" do
    limiter_name = :test_options_combo
    scale = 1000
    limit = 5

    Pleroma.Config.put([:rate_limit, limiter_name], {scale, limit})
    base_bucket_name = "#{limiter_name}:group1"
    opts = RateLimiter.init({limiter_name, bucket_name: base_bucket_name, params: ["id"]})
    id = "100"

    conn = conn(:get, "/?id=#{id}")
    conn = Plug.Conn.fetch_query_params(conn)

    default_bucket_name = "#{limiter_name}:#{RateLimiter.ip(conn)}"
    parametrized_bucket_name = "#{base_bucket_name}:#{id}:#{RateLimiter.ip(conn)}"

    RateLimiter.call(conn, opts)
    assert {1, 4, _, _, _} = ExRated.inspect_bucket(parametrized_bucket_name, scale, limit)
    assert {0, 5, _, _, _} = ExRated.inspect_bucket(default_bucket_name, scale, limit)
  end

  test "optional limits for authenticated users" do
    limiter_name = :test_authenticated
    Ecto.Adapters.SQL.Sandbox.checkout(Pleroma.Repo)

    scale = 1000
    limit = 5
    Pleroma.Config.put([:rate_limit, limiter_name], [{1, 10}, {scale, limit}])

    opts = RateLimiter.init(limiter_name)

    user = insert(:user)
    conn = conn(:get, "/") |> assign(:user, user)
    bucket_name = "#{limiter_name}:#{user.id}"

    conn = RateLimiter.call(conn, opts)
    assert {1, 4, _, _, _} = ExRated.inspect_bucket(bucket_name, scale, limit)

    conn = RateLimiter.call(conn, opts)
    assert {2, 3, _, _, _} = ExRated.inspect_bucket(bucket_name, scale, limit)

    conn = RateLimiter.call(conn, opts)
    assert {3, 2, _, _, _} = ExRated.inspect_bucket(bucket_name, scale, limit)

    conn = RateLimiter.call(conn, opts)
    assert {4, 1, _, _, _} = ExRated.inspect_bucket(bucket_name, scale, limit)

    conn = RateLimiter.call(conn, opts)
    assert {5, 0, to_reset, _, _} = ExRated.inspect_bucket(bucket_name, scale, limit)

    conn = RateLimiter.call(conn, opts)

    assert %{"error" => "Throttled"} = Phoenix.ConnTest.json_response(conn, :too_many_requests)
    assert conn.halted

    Process.sleep(to_reset)

    conn = conn(:get, "/") |> assign(:user, user)

    conn = RateLimiter.call(conn, opts)
    assert {1, 4, _, _, _} = ExRated.inspect_bucket(bucket_name, scale, limit)

    refute conn.status == Plug.Conn.Status.code(:too_many_requests)
    refute conn.resp_body
    refute conn.halted
  end
end
