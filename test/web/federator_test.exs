defmodule Pleroma.Web.FederatorTest do
  alias Pleroma.Web.Federator
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Config
  use Pleroma.DataCase
  import Pleroma.Factory
  import Mock

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

  describe "Publish an activity" do
    setup do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "HI"})

      relay_mock = {
        Pleroma.Web.ActivityPub.Relay,
        [],
        [publish: fn _activity -> send(self(), :relay_publish) end]
      }

      %{activity: activity, relay_mock: relay_mock}
    end

    test "with relays active, it publishes to the relay", %{
      activity: activity,
      relay_mock: relay_mock
    } do
      Config.put([:instance, :allow_relay], true)

      with_mocks([relay_mock]) do
        Federator.handle(:publish, activity)
      end

      assert_received :relay_publish
    end

    test "with relays deactivated, it does not publish to the relay", %{
      activity: activity,
      relay_mock: relay_mock
    } do
      Config.put([:instance, :allow_relay], false)

      with_mocks([relay_mock]) do
        Federator.handle(:publish, activity)
      end

      refute_received :relay_publish
    end
  end
end
