defmodule MockActivityPub do
  def publish_one(ret) do
    {ret, "success"}
  end
end

defmodule Pleroma.Web.Federator.RetryQueueTest do
  use Pleroma.DataCase
  alias Pleroma.Web.Federator.RetryQueue

  @small_retry_count 0
  @hopeless_retry_count 10

  test "failed posts are retried" do
    {:retry, _timeout} = RetryQueue.get_retry_params(@small_retry_count)

    assert {:noreply, %{delivered: 1}} ==
             RetryQueue.handle_info({:send, :ok, MockActivityPub, @small_retry_count}, %{
               delivered: 0
             })
  end

  test "posts that have been tried too many times are dropped" do
    {:drop, _timeout} = RetryQueue.get_retry_params(@hopeless_retry_count)

    assert {:noreply, %{dropped: 1}} ==
             RetryQueue.handle_cast({:maybe_enqueue, %{}, nil, @hopeless_retry_count}, %{
               dropped: 0
             })
  end
end
