# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.FederatorTest do
  alias Pleroma.Web.{CommonAPI, Federator}
  alias Pleroma.Instances
  use Pleroma.DataCase
  import Pleroma.Factory
  import Mock

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

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
      with_mocks([relay_mock]) do
        Federator.handle(:publish, activity)
      end

      assert_received :relay_publish
    end

    test "with relays deactivated, it does not publish to the relay", %{
      activity: activity,
      relay_mock: relay_mock
    } do
      Pleroma.Config.put([:instance, :allow_relay], false)

      with_mocks([relay_mock]) do
        Federator.handle(:publish, activity)
      end

      refute_received :relay_publish

      Pleroma.Config.put([:instance, :allow_relay], true)
    end
  end

  describe "Targets reachability filtering in `publish`" do
    test_with_mock "it federates only to reachable instances via AP",
                   Federator,
                   [:passthrough],
                   [] do
      user = insert(:user)

      {inbox1, inbox2} =
        {"https://domain.com/users/nick1/inbox", "https://domain2.com/users/nick2/inbox"}

      insert(:user, %{
        local: false,
        nickname: "nick1@domain.com",
        ap_id: "https://domain.com/users/nick1",
        info: %{ap_enabled: true, source_data: %{"inbox" => inbox1}}
      })

      insert(:user, %{
        local: false,
        nickname: "nick2@domain2.com",
        ap_id: "https://domain2.com/users/nick2",
        info: %{ap_enabled: true, source_data: %{"inbox" => inbox2}}
      })

      Instances.set_unreachable(
        URI.parse(inbox2).host,
        Instances.reachability_datetime_threshold()
      )

      {:ok, _activity} =
        CommonAPI.post(user, %{"status" => "HI @nick1@domain.com, @nick2@domain2.com!"})

      assert called(Federator.enqueue(:publish_single_ap, %{inbox: inbox1}))
      refute called(Federator.enqueue(:publish_single_ap, %{inbox: inbox2}))
    end

    test_with_mock "it federates only to reachable instances via Websub",
                   Federator,
                   [:passthrough],
                   [] do
      user = insert(:user)
      websub_topic = Pleroma.Web.OStatus.feed_path(user)

      sub1 =
        insert(:websub_subscription, %{
          topic: websub_topic,
          state: "active",
          callback: "http://pleroma.soykaf.com/cb"
        })

      sub2 =
        insert(:websub_subscription, %{
          topic: websub_topic,
          state: "active",
          callback: "https://pleroma2.soykaf.com/cb"
        })

      Instances.set_consistently_unreachable(sub1.callback)

      {:ok, _activity} = CommonAPI.post(user, %{"status" => "HI"})

      assert called(Federator.enqueue(:publish_single_websub, %{callback: sub2.callback}))
      refute called(Federator.enqueue(:publish_single_websub, %{callback: sub1.callback}))
    end

    test_with_mock "it federates only to reachable instances via Salmon",
                   Federator,
                   [:passthrough],
                   [] do
      user = insert(:user)

      remote_user1 =
        insert(:user, %{
          local: false,
          nickname: "nick1@domain.com",
          ap_id: "https://domain.com/users/nick1",
          info: %{salmon: "https://domain.com/salmon"}
        })

      remote_user2 =
        insert(:user, %{
          local: false,
          nickname: "nick2@domain2.com",
          ap_id: "https://domain2.com/users/nick2",
          info: %{salmon: "https://domain2.com/salmon"}
        })

      Instances.set_consistently_unreachable("domain.com")

      {:ok, _activity} =
        CommonAPI.post(user, %{"status" => "HI @nick1@domain.com, @nick2@domain2.com!"})

      assert called(Federator.enqueue(:publish_single_salmon, %{recipient: remote_user2}))
      refute called(Federator.enqueue(:publish_single_websub, %{recipient: remote_user1}))
    end
  end

  describe "Receive an activity" do
    test "successfully processes incoming AP docs with correct origin" do
      params = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "actor" => "http://mastodon.example.org/users/admin",
        "type" => "Create",
        "id" => "http://mastodon.example.org/users/admin/activities/1",
        "object" => %{
          "type" => "Note",
          "content" => "hi world!",
          "id" => "http://mastodon.example.org/users/admin/objects/1",
          "attributedTo" => "http://mastodon.example.org/users/admin"
        },
        "to" => ["https://www.w3.org/ns/activitystreams#Public"]
      }

      {:ok, _activity} = Federator.handle(:incoming_ap_doc, params)
    end

    test "rejects incoming AP docs with incorrect origin" do
      params = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "actor" => "https://niu.moe/users/rye",
        "type" => "Create",
        "id" => "http://mastodon.example.org/users/admin/activities/1",
        "object" => %{
          "type" => "Note",
          "content" => "hi world!",
          "id" => "http://mastodon.example.org/users/admin/objects/1",
          "attributedTo" => "http://mastodon.example.org/users/admin"
        },
        "to" => ["https://www.w3.org/ns/activitystreams#Public"]
      }

      :error = Federator.handle(:incoming_ap_doc, params)
    end
  end
end
