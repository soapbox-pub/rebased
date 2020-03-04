# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.RejectNonPublicTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  alias Pleroma.Web.ActivityPub.MRF.RejectNonPublic

  clear_config([:mrf_rejectnonpublic])

  describe "public message" do
    test "it's allowed when address is public" do
      actor = insert(:user, follower_address: "test-address")

      message = %{
        "actor" => actor.ap_id,
        "to" => ["https://www.w3.org/ns/activitystreams#Public"],
        "cc" => ["https://www.w3.org/ns/activitystreams#Publid"],
        "type" => "Create"
      }

      assert {:ok, message} = RejectNonPublic.filter(message)
    end

    test "it's allowed when cc address contain public address" do
      actor = insert(:user, follower_address: "test-address")

      message = %{
        "actor" => actor.ap_id,
        "to" => ["https://www.w3.org/ns/activitystreams#Public"],
        "cc" => ["https://www.w3.org/ns/activitystreams#Publid"],
        "type" => "Create"
      }

      assert {:ok, message} = RejectNonPublic.filter(message)
    end
  end

  describe "followers message" do
    test "it's allowed when addrer of message in the follower addresses of user and it enabled in config" do
      actor = insert(:user, follower_address: "test-address")

      message = %{
        "actor" => actor.ap_id,
        "to" => ["test-address"],
        "cc" => ["https://www.w3.org/ns/activitystreams#Publid"],
        "type" => "Create"
      }

      Pleroma.Config.put([:mrf_rejectnonpublic, :allow_followersonly], true)
      assert {:ok, message} = RejectNonPublic.filter(message)
    end

    test "it's rejected when addrer of message in the follower addresses of user and it disabled in config" do
      actor = insert(:user, follower_address: "test-address")

      message = %{
        "actor" => actor.ap_id,
        "to" => ["test-address"],
        "cc" => ["https://www.w3.org/ns/activitystreams#Publid"],
        "type" => "Create"
      }

      Pleroma.Config.put([:mrf_rejectnonpublic, :allow_followersonly], false)
      assert {:reject, nil} = RejectNonPublic.filter(message)
    end
  end

  describe "direct message" do
    test "it's allows when direct messages are allow" do
      actor = insert(:user)

      message = %{
        "actor" => actor.ap_id,
        "to" => ["https://www.w3.org/ns/activitystreams#Publid"],
        "cc" => ["https://www.w3.org/ns/activitystreams#Publid"],
        "type" => "Create"
      }

      Pleroma.Config.put([:mrf_rejectnonpublic, :allow_direct], true)
      assert {:ok, message} = RejectNonPublic.filter(message)
    end

    test "it's reject when direct messages aren't allow" do
      actor = insert(:user)

      message = %{
        "actor" => actor.ap_id,
        "to" => ["https://www.w3.org/ns/activitystreams#Publid~~~"],
        "cc" => ["https://www.w3.org/ns/activitystreams#Publid"],
        "type" => "Create"
      }

      Pleroma.Config.put([:mrf_rejectnonpublic, :allow_direct], false)
      assert {:reject, nil} = RejectNonPublic.filter(message)
    end
  end
end
