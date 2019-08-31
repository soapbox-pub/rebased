# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.FederatorTest do
  alias Pleroma.Instances
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Federator
  alias Pleroma.Workers.PublisherWorker

  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory
  import Mock

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)

    :ok
  end

  clear_config_all([:instance, :federating]) do
    Pleroma.Config.put([:instance, :federating], true)
  end

  clear_config([:instance, :allow_relay])
  clear_config([:instance, :rewrite_policy])
  clear_config([:mrf_keyword])

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
        ObanHelpers.perform(all_enqueued(worker: PublisherWorker))
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
        ObanHelpers.perform(all_enqueued(worker: PublisherWorker))
      end

      refute_received :relay_publish
    end
  end

  describe "Targets reachability filtering in `publish`" do
    test "it federates only to reachable instances via AP" do
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

      expected_dt = NaiveDateTime.to_iso8601(dt)

      ObanHelpers.perform(all_enqueued(worker: PublisherWorker))

      assert ObanHelpers.member?(
               %{
                 "op" => "publish_one",
                 "params" => %{"inbox" => inbox1, "unreachable_since" => expected_dt}
               },
               all_enqueued(worker: PublisherWorker)
             )
    end

    test "it federates only to reachable instances via Websub" do
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

      expected_callback = sub2.callback
      expected_dt = NaiveDateTime.to_iso8601(dt)

      ObanHelpers.perform(all_enqueued(worker: PublisherWorker))

      assert ObanHelpers.member?(
               %{
                 "op" => "publish_one",
                 "params" => %{
                   "callback" => expected_callback,
                   "unreachable_since" => expected_dt
                 }
               },
               all_enqueued(worker: PublisherWorker)
             )
    end

    test "it federates only to reachable instances via Salmon" do
      user = insert(:user)

      _remote_user1 =
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

      remote_user2_id = remote_user2.id

      dt = NaiveDateTime.utc_now()
      Instances.set_unreachable(remote_user2.ap_id, dt)

      Instances.set_consistently_unreachable("domain.com")

      {:ok, _activity} =
        CommonAPI.post(user, %{"status" => "HI @nick1@domain.com, @nick2@domain2.com!"})

      expected_dt = NaiveDateTime.to_iso8601(dt)

      ObanHelpers.perform(all_enqueued(worker: PublisherWorker))

      assert ObanHelpers.member?(
               %{
                 "op" => "publish_one",
                 "params" => %{
                   "recipient_id" => remote_user2_id,
                   "unreachable_since" => expected_dt
                 }
               },
               all_enqueued(worker: PublisherWorker)
             )
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

      assert {:ok, job} = Federator.incoming_ap_doc(params)
      assert {:ok, _activity} = ObanHelpers.perform(job)
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

      assert {:ok, job} = Federator.incoming_ap_doc(params)
      assert :error = ObanHelpers.perform(job)
    end

    test "it does not crash if MRF rejects the post" do
      Pleroma.Config.put([:mrf_keyword, :reject], ["lain"])

      Pleroma.Config.put(
        [:instance, :rewrite_policy],
        Pleroma.Web.ActivityPub.MRF.KeywordPolicy
      )

      params =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Poison.decode!()

      assert {:ok, job} = Federator.incoming_ap_doc(params)
      assert :error = ObanHelpers.perform(job)
    end
  end
end
