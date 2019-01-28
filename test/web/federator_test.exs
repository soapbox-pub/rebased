# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.FederatorTest do
  alias Pleroma.Web.Federator
  alias Pleroma.Web.CommonAPI
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
