# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule MockActivityPub do
  def publish_one({ret, waiter}) do
    send(waiter, :complete)
    {ret, "success"}
  end
end

defmodule Pleroma.Web.Federator.RetryQueueTest do
  use Pleroma.DataCase
  alias Pleroma.Web.Federator.RetryQueue

  @small_retry_count 0
  @hopeless_retry_count 10

  setup do
    RetryQueue.reset_stats()
  end

  test "RetryQueue responds to stats request" do
    assert %{delivered: 0, dropped: 0} == RetryQueue.get_stats()
  end

  test "failed posts are retried" do
    {:retry, _timeout} = RetryQueue.get_retry_params(@small_retry_count)

    wait_task =
      Task.async(fn ->
        receive do
          :complete -> :ok
        end
      end)

    RetryQueue.enqueue({:ok, wait_task.pid}, MockActivityPub, @small_retry_count)
    Task.await(wait_task)
    assert %{delivered: 1, dropped: 0} == RetryQueue.get_stats()
  end

  test "posts that have been tried too many times are dropped" do
    {:drop, _timeout} = RetryQueue.get_retry_params(@hopeless_retry_count)

    RetryQueue.enqueue({:ok, nil}, MockActivityPub, @hopeless_retry_count)
    assert %{delivered: 0, dropped: 1} == RetryQueue.get_stats()
  end
end
