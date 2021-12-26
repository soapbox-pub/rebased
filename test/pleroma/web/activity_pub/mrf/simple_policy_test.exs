# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.SimplePolicyTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.Web.ActivityPub.MRF.SimplePolicy
  alias Pleroma.Web.CommonAPI

  setup do:
          clear_config(:mrf_simple,
            media_removal: [],
            media_nsfw: [],
            federated_timeline_removal: [],
            report_removal: [],
            reject: [],
            followers_only: [],
            accept: [],
            avatar_removal: [],
            banner_removal: [],
            reject_deletes: []
          )

  describe "when :media_removal" do
    test "is empty" do
      clear_config([:mrf_simple, :media_removal], [])
      media_message = build_media_message()
      local_message = build_local_message()

      assert SimplePolicy.filter(media_message) == {:ok, media_message}
      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end

    test "has a matching host" do
      clear_config([:mrf_simple, :media_removal], [{"remote.instance", "Some reason"}])
      media_message = build_media_message()
      local_message = build_local_message()

      assert SimplePolicy.filter(media_message) ==
               {:ok,
                media_message
                |> Map.put("object", Map.delete(media_message["object"], "attachment"))}

      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end

    test "match with wildcard domain" do
      clear_config([:mrf_simple, :media_removal], [{"*.remote.instance", "Whatever reason"}])
      media_message = build_media_message()
      local_message = build_local_message()

      assert SimplePolicy.filter(media_message) ==
               {:ok,
                media_message
                |> Map.put("object", Map.delete(media_message["object"], "attachment"))}

      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end
  end

  describe "when :media_nsfw" do
    test "is empty" do
      clear_config([:mrf_simple, :media_nsfw], [])
      media_message = build_media_message()
      local_message = build_local_message()

      assert SimplePolicy.filter(media_message) == {:ok, media_message}
      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end

    test "has a matching host" do
      clear_config([:mrf_simple, :media_nsfw], [{"remote.instance", "Whetever"}])
      media_message = build_media_message()
      local_message = build_local_message()

      assert SimplePolicy.filter(media_message) ==
               {:ok, put_in(media_message, ["object", "sensitive"], true)}

      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end

    test "match with wildcard domain" do
      clear_config([:mrf_simple, :media_nsfw], [{"*.remote.instance", "yeah yeah"}])
      media_message = build_media_message()
      local_message = build_local_message()

      assert SimplePolicy.filter(media_message) ==
               {:ok, put_in(media_message, ["object", "sensitive"], true)}

      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end
  end

  defp build_media_message do
    %{
      "actor" => "https://remote.instance/users/bob",
      "type" => "Create",
      "object" => %{
        "attachment" => [%{}],
        "tag" => ["foo"],
        "sensitive" => false
      }
    }
  end

  describe "when :report_removal" do
    test "is empty" do
      clear_config([:mrf_simple, :report_removal], [])
      report_message = build_report_message()
      local_message = build_local_message()

      assert SimplePolicy.filter(report_message) == {:ok, report_message}
      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end

    test "has a matching host" do
      clear_config([:mrf_simple, :report_removal], [{"remote.instance", "muh"}])
      report_message = build_report_message()
      local_message = build_local_message()

      assert {:reject, _} = SimplePolicy.filter(report_message)
      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end

    test "match with wildcard domain" do
      clear_config([:mrf_simple, :report_removal], [{"*.remote.instance", "suya"}])
      report_message = build_report_message()
      local_message = build_local_message()

      assert {:reject, _} = SimplePolicy.filter(report_message)
      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end
  end

  defp build_report_message do
    %{
      "actor" => "https://remote.instance/users/bob",
      "type" => "Flag"
    }
  end

  describe "when :federated_timeline_removal" do
    test "is empty" do
      clear_config([:mrf_simple, :federated_timeline_removal], [])
      {_, ftl_message} = build_ftl_actor_and_message()
      local_message = build_local_message()

      assert SimplePolicy.filter(ftl_message) == {:ok, ftl_message}
      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end

    test "has a matching host" do
      {actor, ftl_message} = build_ftl_actor_and_message()

      ftl_message_actor_host =
        ftl_message
        |> Map.fetch!("actor")
        |> URI.parse()
        |> Map.fetch!(:host)

      clear_config([:mrf_simple, :federated_timeline_removal], [{ftl_message_actor_host, "uwu"}])
      local_message = build_local_message()

      assert {:ok, ftl_message} = SimplePolicy.filter(ftl_message)
      assert actor.follower_address in ftl_message["to"]
      refute actor.follower_address in ftl_message["cc"]
      refute "https://www.w3.org/ns/activitystreams#Public" in ftl_message["to"]
      assert "https://www.w3.org/ns/activitystreams#Public" in ftl_message["cc"]

      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end

    test "match with wildcard domain" do
      {actor, ftl_message} = build_ftl_actor_and_message()

      ftl_message_actor_host =
        ftl_message
        |> Map.fetch!("actor")
        |> URI.parse()
        |> Map.fetch!(:host)

      clear_config([:mrf_simple, :federated_timeline_removal], [
        {"*." <> ftl_message_actor_host, "owo"}
      ])

      local_message = build_local_message()

      assert {:ok, ftl_message} = SimplePolicy.filter(ftl_message)
      assert actor.follower_address in ftl_message["to"]
      refute actor.follower_address in ftl_message["cc"]
      refute "https://www.w3.org/ns/activitystreams#Public" in ftl_message["to"]
      assert "https://www.w3.org/ns/activitystreams#Public" in ftl_message["cc"]

      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end

    test "has a matching host but only as:Public in to" do
      {_actor, ftl_message} = build_ftl_actor_and_message()

      ftl_message_actor_host =
        ftl_message
        |> Map.fetch!("actor")
        |> URI.parse()
        |> Map.fetch!(:host)

      ftl_message = Map.put(ftl_message, "cc", [])

      clear_config([:mrf_simple, :federated_timeline_removal], [
        {ftl_message_actor_host, "spiderwaifu goes 88w88"}
      ])

      assert {:ok, ftl_message} = SimplePolicy.filter(ftl_message)
      refute "https://www.w3.org/ns/activitystreams#Public" in ftl_message["to"]
      assert "https://www.w3.org/ns/activitystreams#Public" in ftl_message["cc"]
    end
  end

  defp build_ftl_actor_and_message do
    actor = insert(:user)

    {actor,
     %{
       "actor" => actor.ap_id,
       "to" => ["https://www.w3.org/ns/activitystreams#Public", "http://foo.bar/baz"],
       "cc" => [actor.follower_address, "http://foo.bar/qux"]
     }}
  end

  describe "when :reject" do
    test "is empty" do
      clear_config([:mrf_simple, :reject], [])

      remote_message = build_remote_message()

      assert SimplePolicy.filter(remote_message) == {:ok, remote_message}
    end

    test "activity has a matching host" do
      clear_config([:mrf_simple, :reject], [{"remote.instance", ""}])

      remote_message = build_remote_message()

      assert {:reject, _} = SimplePolicy.filter(remote_message)
    end

    test "activity matches with wildcard domain" do
      clear_config([:mrf_simple, :reject], [{"*.remote.instance", ""}])

      remote_message = build_remote_message()

      assert {:reject, _} = SimplePolicy.filter(remote_message)
    end

    test "actor has a matching host" do
      clear_config([:mrf_simple, :reject], [{"remote.instance", ""}])

      remote_user = build_remote_user()

      assert {:reject, _} = SimplePolicy.filter(remote_user)
    end

    test "reject Announce when object would be rejected" do
      clear_config([:mrf_simple, :reject], [{"blocked.tld", ""}])

      announce = %{
        "type" => "Announce",
        "actor" => "https://okay.tld/users/alice",
        "object" => %{"type" => "Note", "actor" => "https://blocked.tld/users/bob"}
      }

      assert {:reject, _} = SimplePolicy.filter(announce)
    end

    test "reject by URI object" do
      clear_config([:mrf_simple, :reject], [{"blocked.tld", ""}])

      announce = %{
        "type" => "Announce",
        "actor" => "https://okay.tld/users/alice",
        "object" => "https://blocked.tld/activities/1"
      }

      assert {:reject, _} = SimplePolicy.filter(announce)
    end
  end

  describe "when :followers_only" do
    test "is empty" do
      clear_config([:mrf_simple, :followers_only], [])
      {_, ftl_message} = build_ftl_actor_and_message()
      local_message = build_local_message()

      assert SimplePolicy.filter(ftl_message) == {:ok, ftl_message}
      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end

    test "has a matching host" do
      actor = insert(:user)
      following_user = insert(:user)
      non_following_user = insert(:user)

      {:ok, _, _, _} = CommonAPI.follow(following_user, actor)

      activity = %{
        "actor" => actor.ap_id,
        "to" => [
          "https://www.w3.org/ns/activitystreams#Public",
          following_user.ap_id,
          non_following_user.ap_id
        ],
        "cc" => [actor.follower_address, "http://foo.bar/qux"]
      }

      dm_activity = %{
        "actor" => actor.ap_id,
        "to" => [
          following_user.ap_id,
          non_following_user.ap_id
        ],
        "cc" => []
      }

      actor_domain =
        activity
        |> Map.fetch!("actor")
        |> URI.parse()
        |> Map.fetch!(:host)

      clear_config([:mrf_simple, :followers_only], [{actor_domain, ""}])

      assert {:ok, new_activity} = SimplePolicy.filter(activity)
      assert actor.follower_address in new_activity["cc"]
      assert following_user.ap_id in new_activity["to"]
      refute "https://www.w3.org/ns/activitystreams#Public" in new_activity["to"]
      refute "https://www.w3.org/ns/activitystreams#Public" in new_activity["cc"]
      refute non_following_user.ap_id in new_activity["to"]
      refute non_following_user.ap_id in new_activity["cc"]

      assert {:ok, new_dm_activity} = SimplePolicy.filter(dm_activity)
      assert new_dm_activity["to"] == [following_user.ap_id]
      assert new_dm_activity["cc"] == []
    end
  end

  describe "when :accept" do
    test "is empty" do
      clear_config([:mrf_simple, :accept], [])

      local_message = build_local_message()
      remote_message = build_remote_message()

      assert SimplePolicy.filter(local_message) == {:ok, local_message}
      assert SimplePolicy.filter(remote_message) == {:ok, remote_message}
    end

    test "is not empty but activity doesn't have a matching host" do
      clear_config([:mrf_simple, :accept], [{"non.matching.remote", ""}])

      local_message = build_local_message()
      remote_message = build_remote_message()

      assert SimplePolicy.filter(local_message) == {:ok, local_message}
      assert {:reject, _} = SimplePolicy.filter(remote_message)
    end

    test "activity has a matching host" do
      clear_config([:mrf_simple, :accept], [{"remote.instance", ""}])

      local_message = build_local_message()
      remote_message = build_remote_message()

      assert SimplePolicy.filter(local_message) == {:ok, local_message}
      assert SimplePolicy.filter(remote_message) == {:ok, remote_message}
    end

    test "activity matches with wildcard domain" do
      clear_config([:mrf_simple, :accept], [{"*.remote.instance", ""}])

      local_message = build_local_message()
      remote_message = build_remote_message()

      assert SimplePolicy.filter(local_message) == {:ok, local_message}
      assert SimplePolicy.filter(remote_message) == {:ok, remote_message}
    end

    test "actor has a matching host" do
      clear_config([:mrf_simple, :accept], [{"remote.instance", ""}])

      remote_user = build_remote_user()

      assert SimplePolicy.filter(remote_user) == {:ok, remote_user}
    end
  end

  describe "when :avatar_removal" do
    test "is empty" do
      clear_config([:mrf_simple, :avatar_removal], [])

      remote_user = build_remote_user()

      assert SimplePolicy.filter(remote_user) == {:ok, remote_user}
    end

    test "is not empty but it doesn't have a matching host" do
      clear_config([:mrf_simple, :avatar_removal], [{"non.matching.remote", ""}])

      remote_user = build_remote_user()

      assert SimplePolicy.filter(remote_user) == {:ok, remote_user}
    end

    test "has a matching host" do
      clear_config([:mrf_simple, :avatar_removal], [{"remote.instance", ""}])

      remote_user = build_remote_user()
      {:ok, filtered} = SimplePolicy.filter(remote_user)

      refute filtered["icon"]
    end

    test "match with wildcard domain" do
      clear_config([:mrf_simple, :avatar_removal], [{"*.remote.instance", ""}])

      remote_user = build_remote_user()
      {:ok, filtered} = SimplePolicy.filter(remote_user)

      refute filtered["icon"]
    end
  end

  describe "when :banner_removal" do
    test "is empty" do
      clear_config([:mrf_simple, :banner_removal], [])

      remote_user = build_remote_user()

      assert SimplePolicy.filter(remote_user) == {:ok, remote_user}
    end

    test "is not empty but it doesn't have a matching host" do
      clear_config([:mrf_simple, :banner_removal], [{"non.matching.remote", ""}])

      remote_user = build_remote_user()

      assert SimplePolicy.filter(remote_user) == {:ok, remote_user}
    end

    test "has a matching host" do
      clear_config([:mrf_simple, :banner_removal], [{"remote.instance", ""}])

      remote_user = build_remote_user()
      {:ok, filtered} = SimplePolicy.filter(remote_user)

      refute filtered["image"]
    end

    test "match with wildcard domain" do
      clear_config([:mrf_simple, :banner_removal], [{"*.remote.instance", ""}])

      remote_user = build_remote_user()
      {:ok, filtered} = SimplePolicy.filter(remote_user)

      refute filtered["image"]
    end
  end

  describe "when :reject_deletes is empty" do
    setup do: clear_config([:mrf_simple, :reject_deletes], [])

    test "it accepts deletions even from rejected servers" do
      clear_config([:mrf_simple, :reject], [{"remote.instance", ""}])

      deletion_message = build_remote_deletion_message()

      assert SimplePolicy.filter(deletion_message) == {:ok, deletion_message}
    end

    test "it accepts deletions even from non-whitelisted servers" do
      clear_config([:mrf_simple, :accept], [{"non.matching.remote", ""}])

      deletion_message = build_remote_deletion_message()

      assert SimplePolicy.filter(deletion_message) == {:ok, deletion_message}
    end
  end

  describe "when :reject_deletes is not empty but it doesn't have a matching host" do
    setup do: clear_config([:mrf_simple, :reject_deletes], [{"non.matching.remote", ""}])

    test "it accepts deletions even from rejected servers" do
      clear_config([:mrf_simple, :reject], [{"remote.instance", ""}])

      deletion_message = build_remote_deletion_message()

      assert SimplePolicy.filter(deletion_message) == {:ok, deletion_message}
    end

    test "it accepts deletions even from non-whitelisted servers" do
      clear_config([:mrf_simple, :accept], [{"non.matching.remote", ""}])

      deletion_message = build_remote_deletion_message()

      assert SimplePolicy.filter(deletion_message) == {:ok, deletion_message}
    end
  end

  describe "when :reject_deletes has a matching host" do
    setup do: clear_config([:mrf_simple, :reject_deletes], [{"remote.instance", ""}])

    test "it rejects the deletion" do
      deletion_message = build_remote_deletion_message()

      assert {:reject, _} = SimplePolicy.filter(deletion_message)
    end
  end

  describe "when :reject_deletes match with wildcard domain" do
    setup do: clear_config([:mrf_simple, :reject_deletes], [{"*.remote.instance", ""}])

    test "it rejects the deletion" do
      deletion_message = build_remote_deletion_message()

      assert {:reject, _} = SimplePolicy.filter(deletion_message)
    end
  end

  defp build_local_message do
    %{
      "actor" => "#{Pleroma.Web.Endpoint.url()}/users/alice",
      "to" => [],
      "cc" => []
    }
  end

  defp build_remote_message do
    %{"actor" => "https://remote.instance/users/bob"}
  end

  defp build_remote_user do
    %{
      "id" => "https://remote.instance/users/bob",
      "icon" => %{
        "url" => "http://example.com/image.jpg",
        "type" => "Image"
      },
      "image" => %{
        "url" => "http://example.com/image.jpg",
        "type" => "Image"
      },
      "type" => "Person"
    }
  end

  defp build_remote_deletion_message do
    %{
      "type" => "Delete",
      "actor" => "https://remote.instance/users/bob"
    }
  end
end
