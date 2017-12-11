defmodule Pleroma.Web.FederatorTest do
  alias Pleroma.Web.Federator
  use Pleroma.DataCase

  test "enqueues an element according to priority" do
    queue = [%{item: 1, priority: 2}]

    new_queue = Federator.enqueue_sorted(queue, 2, 1)
    assert new_queue == [%{item: 2, priority: 1}, %{item: 1, priority: 2}]

    new_queue = Federator.enqueue_sorted(queue, 2, 3)
    assert new_queue == [%{item: 1, priority: 2}, %{item: 2, priority: 3}]
  end

  test "pop first item" do
    queue = [%{item: 2, priority: 1}, %{item: 1, priority: 2}]

    assert {2, [%{item: 1, priority: 2}]} = Federator.queue_pop(queue)
  end
end
