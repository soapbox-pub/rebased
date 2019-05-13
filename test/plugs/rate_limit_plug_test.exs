defmodule Pleroma.Plugs.RateLimitPlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Pleroma.Plugs.RateLimitPlug

  @opts RateLimitPlug.init(%{max_requests: 5, interval: 1})

  setup do
    enabled = Pleroma.Config.get([:app_account_creation, :enabled])

    Pleroma.Config.put([:app_account_creation, :enabled], true)

    on_exit(fn ->
      Pleroma.Config.put([:app_account_creation, :enabled], enabled)
    end)

    :ok
  end

  test "it restricts by opts" do
    conn = conn(:get, "/")
    bucket_name = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
    ms = 1000

    conn = RateLimitPlug.call(conn, @opts)
    {1, 4, _, _, _} = ExRated.inspect_bucket(bucket_name, ms, 5)
    conn = RateLimitPlug.call(conn, @opts)
    {2, 3, _, _, _} = ExRated.inspect_bucket(bucket_name, ms, 5)
    conn = RateLimitPlug.call(conn, @opts)
    {3, 2, _, _, _} = ExRated.inspect_bucket(bucket_name, ms, 5)
    conn = RateLimitPlug.call(conn, @opts)
    {4, 1, _, _, _} = ExRated.inspect_bucket(bucket_name, ms, 5)
    conn = RateLimitPlug.call(conn, @opts)
    {5, 0, to_reset, _, _} = ExRated.inspect_bucket(bucket_name, ms, 5)
    conn = RateLimitPlug.call(conn, @opts)
    assert conn.status == 403
    assert conn.halted
    assert conn.resp_body == "{\"error\":\"Rate limit exceeded.\"}"

    Process.sleep(to_reset)

    conn = conn(:get, "/")
    conn = RateLimitPlug.call(conn, @opts)
    {1, 4, _, _, _} = ExRated.inspect_bucket(bucket_name, ms, 5)
    refute conn.status == 403
    refute conn.halted
    refute conn.resp_body
  end
end
