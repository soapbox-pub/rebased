# Pleroma: A lightweight social networking server
# Copyright © 2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.PublisherTest do
  use Pleroma.DataCase

  import Pleroma.Factory
  import Tesla.Mock
  import Mock

  alias Pleroma.Activity
  alias Pleroma.Instances
  alias Pleroma.Web.ActivityPub.Publisher

  @as_public "https://www.w3.org/ns/activitystreams#Public"

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "determine_inbox/2" do
    test "it returns sharedInbox for messages involving as:Public in to" do
      user =
        insert(:user, %{
          info: %{source_data: %{"endpoints" => %{"sharedInbox" => "http://example.com/inbox"}}}
        })

      activity = %Activity{
        data: %{"to" => [@as_public], "cc" => [user.follower_address]}
      }

      assert Publisher.determine_inbox(activity, user) == "http://example.com/inbox"
    end

    test "it returns sharedInbox for messages involving as:Public in cc" do
      user =
        insert(:user, %{
          info: %{source_data: %{"endpoints" => %{"sharedInbox" => "http://example.com/inbox"}}}
        })

      activity = %Activity{
        data: %{"cc" => [@as_public], "to" => [user.follower_address]}
      }

      assert Publisher.determine_inbox(activity, user) == "http://example.com/inbox"
    end

    test "it returns sharedInbox for messages involving multiple recipients in to" do
      user =
        insert(:user, %{
          info: %{source_data: %{"endpoints" => %{"sharedInbox" => "http://example.com/inbox"}}}
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
          info: %{source_data: %{"endpoints" => %{"sharedInbox" => "http://example.com/inbox"}}}
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
        insert(:user, %{
          info: %{
            source_data: %{
              "inbox" => "http://example.com/personal-inbox",
              "endpoints" => %{"sharedInbox" => "http://example.com/inbox"}
            }
          }
        })

      user_two = insert(:user)

      activity = %Activity{
        data: %{"to" => [user_two.ap_id], "cc" => [user.ap_id]}
      }

      assert Publisher.determine_inbox(activity, user) == "http://example.com/inbox"
    end

    test "it returns inbox for messages involving single recipients in total" do
      user =
        insert(:user, %{
          info: %{
            source_data: %{
              "inbox" => "http://example.com/personal-inbox",
              "endpoints" => %{"sharedInbox" => "http://example.com/inbox"}
            }
          }
        })

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

      assert {:error, _} = Publisher.publish_one(%{inbox: inbox, json: "{}", actor: actor, id: 1})

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

      assert {:error, _} =
               Publisher.publish_one(%{
                 inbox: inbox,
                 json: "{}",
                 actor: actor,
                 id: 1,
                 unreachable_since: NaiveDateTime.utc_now()
               })

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
          info: %{
            ap_enabled: true,
            source_data: %{"inbox" => "https://domain.com/users/nick1/inbox"}
          }
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
                 actor: actor,
                 id: note_activity.data["id"]
               })
             )
    end
  end
end