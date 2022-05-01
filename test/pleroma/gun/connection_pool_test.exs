# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Gun.ConnectionPoolTest do
  use Pleroma.DataCase

  import Mox
  import ExUnit.CaptureLog
  alias Pleroma.Gun.ConnectionPool

  defp gun_mock(_) do
    Pleroma.GunMock
    |> stub(:open, fn _, _, _ -> Task.start_link(fn -> Process.sleep(100) end) end)
    |> stub(:await_up, fn _, _ -> {:ok, :http} end)
    |> stub(:set_owner, fn _, _ -> :ok end)

    :ok
  end

  setup :gun_mock

  test "gives the same connection to 2 concurrent requests" do
    Enum.map(
      [
        "http://www.korean-books.com.kp/KBMbooks/en/periodic/pictorial/20200530163914.pdf",
        "http://www.korean-books.com.kp/KBMbooks/en/periodic/pictorial/20200528183427.pdf"
      ],
      fn uri ->
        uri = URI.parse(uri)
        task_parent = self()

        Task.start_link(fn ->
          {:ok, conn} = ConnectionPool.get_conn(uri, [])
          ConnectionPool.release_conn(conn)
          send(task_parent, conn)
        end)
      end
    )

    [pid, pid] =
      for _ <- 1..2 do
        receive do
          pid -> pid
        end
      end
  end

  @tag :erratic
  test "connection limit is respected with concurrent requests" do
    clear_config([:connections_pool, :max_connections]) do
      clear_config([:connections_pool, :max_connections], 1)
      # The supervisor needs a reboot to apply the new config setting
      Process.exit(Process.whereis(Pleroma.Gun.ConnectionPool.WorkerSupervisor), :kill)

      on_exit(fn ->
        Process.exit(Process.whereis(Pleroma.Gun.ConnectionPool.WorkerSupervisor), :kill)
      end)
    end

    capture_log(fn ->
      Enum.map(
        [
          "https://ninenines.eu/",
          "https://youtu.be/PFGwMiDJKNY"
        ],
        fn uri ->
          uri = URI.parse(uri)
          task_parent = self()

          Task.start_link(fn ->
            result = ConnectionPool.get_conn(uri, [])
            # Sleep so that we don't end up with a situation,
            # where request from the second process gets processed
            # only after the first process already released the connection
            Process.sleep(50)

            case result do
              {:ok, pid} ->
                ConnectionPool.release_conn(pid)

              _ ->
                nil
            end

            send(task_parent, result)
          end)
        end
      )

      [{:error, :pool_full}, {:ok, _pid}] =
        for _ <- 1..2 do
          receive do
            result -> result
          end
        end
        |> Enum.sort()
    end)
  end
end
