# Pleroma: A lightweight social networking server
# Copyright © 2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.PublisherTest do
  use Pleroma.DataCase

  import Pleroma.Factory

  alias Pleroma.Activity
  alias Pleroma.Web.ActivityPub.Publisher

  @as_public "https://www.w3.org/ns/activitystreams#Public"

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
end
