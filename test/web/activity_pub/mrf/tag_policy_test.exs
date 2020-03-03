# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.TagPolicyTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  alias Pleroma.Web.ActivityPub.MRF.TagPolicy
  @public "https://www.w3.org/ns/activitystreams#Public"

  describe "mrf_tag:disable-any-subscription" do
    test "rejects message" do
      actor = insert(:user, tags: ["mrf_tag:disable-any-subscription"])
      message = %{"object" => actor.ap_id, "type" => "Follow"}
      assert {:reject, nil} = TagPolicy.filter(message)
    end
  end

  describe "mrf_tag:disable-remote-subscription" do
    test "rejects non-local follow requests" do
      actor = insert(:user, tags: ["mrf_tag:disable-remote-subscription"])
      follower = insert(:user, tags: ["mrf_tag:disable-remote-subscription"], local: false)
      message = %{"object" => actor.ap_id, "type" => "Follow", "actor" => follower.ap_id}
      assert {:reject, nil} = TagPolicy.filter(message)
    end

    test "allows non-local follow requests" do
      actor = insert(:user, tags: ["mrf_tag:disable-remote-subscription"])
      follower = insert(:user, tags: ["mrf_tag:disable-remote-subscription"], local: true)
      message = %{"object" => actor.ap_id, "type" => "Follow", "actor" => follower.ap_id}
      assert {:ok, message} = TagPolicy.filter(message)
    end
  end

  describe "mrf_tag:sandbox" do
    test "removes from public timelines" do
      actor = insert(:user, tags: ["mrf_tag:sandbox"])

      message = %{
        "actor" => actor.ap_id,
        "type" => "Create",
        "object" => %{},
        "to" => [@public, "f"],
        "cc" => [@public, "d"]
      }

      except_message = %{
        "actor" => actor.ap_id,
        "type" => "Create",
        "object" => %{"to" => ["f", actor.follower_address], "cc" => ["d"]},
        "to" => ["f", actor.follower_address],
        "cc" => ["d"]
      }

      assert TagPolicy.filter(message) == {:ok, except_message}
    end
  end

  describe "mrf_tag:force-unlisted" do
    test "removes from the federated timeline" do
      actor = insert(:user, tags: ["mrf_tag:force-unlisted"])

      message = %{
        "actor" => actor.ap_id,
        "type" => "Create",
        "object" => %{},
        "to" => [@public, "f"],
        "cc" => [actor.follower_address, "d"]
      }

      except_message = %{
        "actor" => actor.ap_id,
        "type" => "Create",
        "object" => %{"to" => ["f", actor.follower_address], "cc" => ["d", @public]},
        "to" => ["f", actor.follower_address],
        "cc" => ["d", @public]
      }

      assert TagPolicy.filter(message) == {:ok, except_message}
    end
  end

  describe "mrf_tag:media-strip" do
    test "removes attachments" do
      actor = insert(:user, tags: ["mrf_tag:media-strip"])

      message = %{
        "actor" => actor.ap_id,
        "type" => "Create",
        "object" => %{"attachment" => ["file1"]}
      }

      except_message = %{
        "actor" => actor.ap_id,
        "type" => "Create",
        "object" => %{}
      }

      assert TagPolicy.filter(message) == {:ok, except_message}
    end
  end

  describe "mrf_tag:media-force-nsfw" do
    test "Mark as sensitive on presence of attachments" do
      actor = insert(:user, tags: ["mrf_tag:media-force-nsfw"])

      message = %{
        "actor" => actor.ap_id,
        "type" => "Create",
        "object" => %{"tag" => ["test"], "attachment" => ["file1"]}
      }

      except_message = %{
        "actor" => actor.ap_id,
        "type" => "Create",
        "object" => %{"tag" => ["test", "nsfw"], "attachment" => ["file1"], "sensitive" => true}
      }

      assert TagPolicy.filter(message) == {:ok, except_message}
    end
  end
end
