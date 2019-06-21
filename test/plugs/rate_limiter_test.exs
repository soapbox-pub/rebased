defmodule Pleroma.Plugs.RateLimiterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Pleroma.Plugs.RateLimiter

  import Pleroma.Factory

  @limiter_name :testing

  test "init/1" do
    Pleroma.Config.put([:rate_limit, @limiter_name], {1, 1})

    assert {@limiter_name, {1, 1}} == RateLimiter.init(@limiter_name)
    assert nil == RateLimiter.init(:foo)
  end

  test "ip/1" do
    assert "127.0.0.1" == RateLimiter.ip(%{remote_ip: {127, 0, 0, 1}})
  end

  test "it restricts by opts" do
    scale = 1000
    limit = 5

    Pleroma.Config.put([:rate_limit, @limiter_name], {scale, limit})

    opts = RateLimiter.init(@limiter_name)
    conn = conn(:get, "/")
    bucket_name = "#{@limiter_name}:#{RateLimiter.ip(conn)}"

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

  test "optional limits for authenticated users" do
    Ecto.Adapters.SQL.Sandbox.checkout(Pleroma.Repo)

    scale = 1000
    limit = 5
    Pleroma.Config.put([:rate_limit, @limiter_name], [{1, 10}, {scale, limit}])

    opts = RateLimiter.init(@limiter_name)

    user = insert(:user)
    conn = conn(:get, "/") |> assign(:user, user)
    bucket_name = "#{@limiter_name}:#{user.id}"

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
