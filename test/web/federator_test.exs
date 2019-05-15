# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.FederatorTest do
  alias Pleroma.Instances
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Federator
  use Pleroma.DataCase
  import Pleroma.Factory
  import Mock

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
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
        Federator.publish(activity)
      end

      assert_received :relay_publish
    end

    test "with relays deactivated, it does not publish to the relay", %{
      activity: activity,
      relay_mock: relay_mock
    } do
      Pleroma.Config.put([:instance, :allow_relay], false)

      with_mocks([relay_mock]) do
        Federator.publish(activity)
      end

      refute_received :relay_publish

      Pleroma.Config.put([:instance, :allow_relay], true)
    end
  end

  describe "Targets reachability filtering in `publish`" do
    test_with_mock "it federates only to reachable instances via AP",
                   Pleroma.Web.ActivityPub.Publisher,
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

      dt = NaiveDateTime.utc_now()
      Instances.set_unreachable(inbox1, dt)

      Instances.set_consistently_unreachable(URI.parse(inbox2).host)

      {:ok, _activity} =
        CommonAPI.post(user, %{"status" => "HI @nick1@domain.com, @nick2@domain2.com!"})

      assert called(
               Pleroma.Web.ActivityPub.Publisher.publish_one(%{
                 inbox: inbox1,
                 unreachable_since: dt
               })
             )

      refute called(Pleroma.Web.ActivityPub.Publisher.publish_one(%{inbox: inbox2}))
    end

    test_with_mock "it federates only to reachable instances via Websub",
                   Pleroma.Web.Websub,
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

      dt = NaiveDateTime.utc_now()
      Instances.set_unreachable(sub2.callback, dt)

      Instances.set_consistently_unreachable(sub1.callback)

      {:ok, _activity} = CommonAPI.post(user, %{"status" => "HI"})

      assert called(
               Pleroma.Web.Websub.publish_one(%{
                 callback: sub2.callback,
                 unreachable_since: dt
               })
             )

      refute called(Pleroma.Web.Websub.publish_one(%{callback: sub1.callback}))
    end

    test_with_mock "it federates only to reachable instances via Salmon",
                   Pleroma.Web.Salmon,
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

      dt = NaiveDateTime.utc_now()
      Instances.set_unreachable(remote_user2.ap_id, dt)

      Instances.set_consistently_unreachable("domain.com")

      {:ok, _activity} =
        CommonAPI.post(user, %{"status" => "HI @nick1@domain.com, @nick2@domain2.com!"})

      assert called(
               Pleroma.Web.Salmon.publish_one(%{
                 recipient: remote_user2,
                 unreachable_since: dt
               })
             )

      refute called(Pleroma.Web.Salmon.publish_one(%{recipient: remote_user1}))
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

      {:ok, _activity} = Federator.incoming_ap_doc(params)
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

      :error = Federator.incoming_ap_doc(params)
    end
  end
end
