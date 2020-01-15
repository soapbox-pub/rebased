# Pleroma: A lightweight social networking server
# Copyright © 2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.PublisherTest do
  use Pleroma.Web.ConnCase

  import ExUnit.CaptureLog
  import Pleroma.Factory
  import Tesla.Mock
  import Mock

  alias Pleroma.Activity
  alias Pleroma.Instances
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.Publisher
  alias Pleroma.Web.CommonAPI

  @as_public "https://www.w3.org/ns/activitystreams#Public"

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "gather_webfinger_links/1" do
    test "it returns links" do
      user = insert(:user)

      expected_links = [
        %{"href" => user.ap_id, "rel" => "self", "type" => "application/activity+json"},
        %{
          "href" => user.ap_id,
          "rel" => "self",
          "type" => "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\""
        },
        %{
          "rel" => "http://ostatus.org/schema/1.0/subscribe",
          "template" => "#{Pleroma.Web.base_url()}/ostatus_subscribe?acct={uri}"
        }
      ]

      assert expected_links == Publisher.gather_webfinger_links(user)
    end
  end

  describe "determine_inbox/2" do
    test "it returns sharedInbox for messages involving as:Public in to" do
      user =
        insert(:user, %{
          source_data: %{"endpoints" => %{"sharedInbox" => "http://example.com/inbox"}}
        })

      activity = %Activity{
        data: %{"to" => [@as_public], "cc" => [user.follower_address]}
      }

      assert Publisher.determine_inbox(activity, user) == "http://example.com/inbox"
    end

    test "it returns sharedInbox for messages involving as:Public in cc" do
      user =
        insert(:user, %{
          source_data: %{"endpoints" => %{"sharedInbox" => "http://example.com/inbox"}}
        })

      activity = %Activity{
        data: %{"cc" => [@as_public], "to" => [user.follower_address]}
      }

      assert Publisher.determine_inbox(activity, user) == "http://example.com/inbox"
    end

    test "it returns sharedInbox for messages involving multiple recipients in to" do
      user =
        insert(:user, %{
          source_data: %{"endpoints" => %{"sharedInbox" => "http://example.com/inbox"}}
        })

      user_two = insert(:user)
      user_three = insert(:user)

      activity = %Activity{
        data: %{"cc" => [], "to" => [user.ap_id, user_two.ap_id, user_three.ap_id]}
      }

      assert Publisher.determine_inbox(activity, user) == "http://example.com/inbox"
    end

    test "it returns sharedInbox for messages involving multiple recipients in cc" do
      user =
        insert(:user, %{
          source_data: %{"endpoints" => %{"sharedInbox" => "http://example.com/inbox"}}
        })

      user_two = insert(:user)
      user_three = insert(:user)

      activity = %Activity{
        data: %{"to" => [], "cc" => [user.ap_id, user_two.ap_id, user_three.ap_id]}
      }

      assert Publisher.determine_inbox(activity, user) == "http://example.com/inbox"
    end

    test "it returns sharedInbox for messages involving multiple recipients in total" do
      user =
        insert(:user,
          source_data: %{
            "inbox" => "http://example.com/personal-inbox",
            "endpoints" => %{"sharedInbox" => "http://example.com/inbox"}
          }
        )

      user_two = insert(:user)

      activity = %Activity{
        data: %{"to" => [user_two.ap_id], "cc" => [user.ap_id]}
      }

      assert Publisher.determine_inbox(activity, user) == "http://example.com/inbox"
    end

    test "it returns inbox for messages involving single recipients in total" do
      user =
        insert(:user,
          source_data: %{
            "inbox" => "http://example.com/personal-inbox",
            "endpoints" => %{"sharedInbox" => "http://example.com/inbox"}
          }
        )

      activity = %Activity{
        data: %{"to" => [user.ap_id], "cc" => []}
      }

      assert Publisher.determine_inbox(activity, user) == "http://example.com/personal-inbox"
    end
  end

  describe "publish_one/1" do
    test_with_mock "calls `Instances.set_reachable` on successful federation if `unreachable_since` is not specified",
                   Instances,
                   [:passthrough],
                   [] do
      actor = insert(:user)
      inbox = "http://200.site/users/nick1/inbox"

      assert {:ok, _} = Publisher.publish_one(%{inbox: inbox, json: "{}", actor: actor, id: 1})

      assert called(Instances.set_reachable(inbox))
    end

    test_with_mock "calls `Instances.set_reachable` on successful federation if `unreachable_since` is set",
                   Instances,
                   [:passthrough],
                   [] do
      actor = insert(:user)
      inbox = "http://200.site/users/nick1/inbox"

      assert {:ok, _} =
               Publisher.publish_one(%{
                 inbox: inbox,
                 json: "{}",
                 actor: actor,
                 id: 1,
                 unreachable_since: NaiveDateTime.utc_now()
               })

      assert called(Instances.set_reachable(inbox))
    end

    test_with_mock "does NOT call `Instances.set_reachable` on successful federation if `unreachable_since` is nil",
                   Instances,
                   [:passthrough],
                   [] do
      actor = insert(:user)
      inbox = "http://200.site/users/nick1/inbox"

      assert {:ok, _} =
               Publisher.publish_one(%{
                 inbox: inbox,
                 json: "{}",
                 actor: actor,
                 id: 1,
                 unreachable_since: nil
               })

      refute called(Instances.set_reachable(inbox))
    end

    test_with_mock "calls `Instances.set_unreachable` on target inbox on non-2xx HTTP response code",
                   Instances,
                   [:passthrough],
                   [] do
      actor = insert(:user)
      inbox = "http://404.site/users/nick1/inbox"

      assert {:error, _} = Publisher.publish_one(%{inbox: inbox, json: "{}", actor: actor, id: 1})

      assert called(Instances.set_unreachable(inbox))
    end

    test_with_mock "it calls `Instances.set_unreachable` on target inbox on request error of any kind",
                   Instances,
                   [:passthrough],
                   [] do
      actor = insert(:user)
      inbox = "http://connrefused.site/users/nick1/inbox"

      assert capture_log(fn ->
               assert {:error, _} =
                        Publisher.publish_one(%{inbox: inbox, json: "{}", actor: actor, id: 1})
             end) =~ "connrefused"

      assert called(Instances.set_unreachable(inbox))
    end

    test_with_mock "does NOT call `Instances.set_unreachable` if target is reachable",
                   Instances,
                   [:passthrough],
                   [] do
      actor = insert(:user)
      inbox = "http://200.site/users/nick1/inbox"

      assert {:ok, _} = Publisher.publish_one(%{inbox: inbox, json: "{}", actor: actor, id: 1})

      refute called(Instances.set_unreachable(inbox))
    end

    test_with_mock "does NOT call `Instances.set_unreachable` if target instance has non-nil `unreachable_since`",
                   Instances,
                   [:passthrough],
                   [] do
      actor = insert(:user)
      inbox = "http://connrefused.site/users/nick1/inbox"

      assert capture_log(fn ->
               assert {:error, _} =
                        Publisher.publish_one(%{
                          inbox: inbox,
                          json: "{}",
                          actor: actor,
                          id: 1,
                          unreachable_since: NaiveDateTime.utc_now()
                        })
             end) =~ "connrefused"

      refute called(Instances.set_unreachable(inbox))
    end
  end

  describe "publish/2" do
    test_with_mock "publishes an activity with BCC to all relevant peers.",
                   Pleroma.Web.Federator.Publisher,
                   [:passthrough],
                   [] do
      follower =
        insert(:user,
          local: false,
          source_data: %{"inbox" => "https://domain.com/users/nick1/inbox"},
          ap_enabled: true
        )

      actor = insert(:user, follower_address: follower.ap_id)
      user = insert(:user)

      {:ok, _follower_one} = Pleroma.User.follow(follower, actor)
      actor = refresh_record(actor)

      note_activity =
        insert(:note_activity,
          recipients: [follower.ap_id],
          data_attrs: %{"bcc" => [user.ap_id]}
        )

      res = Publisher.publish(actor, note_activity)
      assert res == :ok

      assert called(
               Pleroma.Web.Federator.Publisher.enqueue_one(Publisher, %{
                 inbox: "https://domain.com/users/nick1/inbox",
                 actor_id: actor.id,
                 id: note_activity.data["id"]
               })
             )
    end

    test_with_mock "publishes a delete activity to peers who signed fetch requests to the create acitvity/object.",
                   Pleroma.Web.Federator.Publisher,
                   [:passthrough],
                   [] do
      fetcher =
        insert(:user,
          local: false,
          source_data: %{"inbox" => "https://domain.com/users/nick1/inbox"},
          ap_enabled: true
        )

      another_fetcher =
        insert(:user,
          local: false,
          source_data: %{"inbox" => "https://domain2.com/users/nick1/inbox"},
          ap_enabled: true
        )

      actor = insert(:user)

      note_activity = insert(:note_activity, user: actor)
      object = Object.normalize(note_activity)

      activity_path = String.trim_leading(note_activity.data["id"], Pleroma.Web.Endpoint.url())
      object_path = String.trim_leading(object.data["id"], Pleroma.Web.Endpoint.url())

      build_conn()
      |> put_req_header("accept", "application/activity+json")
      |> assign(:user, fetcher)
      |> get(object_path)
      |> json_response(200)

      build_conn()
      |> put_req_header("accept", "application/activity+json")
      |> assign(:user, another_fetcher)
      |> get(activity_path)
      |> json_response(200)

      {:ok, delete} = CommonAPI.delete(note_activity.id, actor)

      res = Publisher.publish(actor, delete)
      assert res == :ok

      assert called(
               Pleroma.Web.Federator.Publisher.enqueue_one(Publisher, %{
                 inbox: "https://domain.com/users/nick1/inbox",
                 actor_id: actor.id,
                 id: delete.data["id"]
               })
             )

      assert called(
               Pleroma.Web.Federator.Publisher.enqueue_one(Publisher, %{
                 inbox: "https://domain2.com/users/nick1/inbox",
                 actor_id: actor.id,
                 id: delete.data["id"]
               })
             )
    end
  end
end
