# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
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

  setup_all do: clear_config([:instance, :federating], true)
  setup do: clear_config([:instance, :allow_relay])
  setup do: clear_config([:mrf, :policies])
  setup do: clear_config([:mrf_keyword])

  describe "Publish an activity" do
    setup do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{status: "HI"})

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
      clear_config([:instance, :allow_relay], false)

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
        inbox: inbox1,
        ap_enabled: true
      })

      insert(:user, %{
        local: false,
        nickname: "nick2@domain2.com",
        ap_id: "https://domain2.com/users/nick2",
        inbox: inbox2,
        ap_enabled: true
      })

      dt = NaiveDateTime.utc_now()
      Instances.set_unreachable(inbox1, dt)

      Instances.set_consistently_unreachable(URI.parse(inbox2).host)

      {:ok, _activity} =
        CommonAPI.post(user, %{status: "HI @nick1@domain.com, @nick2@domain2.com!"})

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
          "attributedTo" => "http://mastodon.example.org/users/admin",
          "to" => ["https://www.w3.org/ns/activitystreams#Public"]
        },
        "to" => ["https://www.w3.org/ns/activitystreams#Public"]
      }

      assert {:ok, job} = Federator.incoming_ap_doc(params)
      assert {:ok, _activity} = ObanHelpers.perform(job)

      assert {:ok, job} = Federator.incoming_ap_doc(params)
      assert {:error, :already_present} = ObanHelpers.perform(job)
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
          "attributedTo" => "http://mastodon.example.org/users/admin",
          "to" => ["https://www.w3.org/ns/activitystreams#Public"]
        },
        "to" => ["https://www.w3.org/ns/activitystreams#Public"]
      }

      assert {:ok, job} = Federator.incoming_ap_doc(params)
      assert {:cancel, :origin_containment_failed} = ObanHelpers.perform(job)
    end

    test "it does not crash if MRF rejects the post" do
      clear_config([:mrf_keyword, :reject], ["lain"])

      clear_config(
        [:mrf, :policies],
        Pleroma.Web.ActivityPub.MRF.KeywordPolicy
      )

      params =
        File.read!("test/fixtures/mastodon-post-activity.json")
        |> Jason.decode!()

      assert {:ok, job} = Federator.incoming_ap_doc(params)
      assert {:cancel, _} = ObanHelpers.perform(job)
    end
  end
end
