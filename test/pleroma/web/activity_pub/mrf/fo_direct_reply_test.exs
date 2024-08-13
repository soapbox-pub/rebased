# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.FODirectReplyTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  require Pleroma.Constants

  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.MRF.FODirectReply
  alias Pleroma.Web.CommonAPI

  test "replying to followers-only/private is changed to direct" do
    batman = insert(:user, nickname: "batman")
    robin = insert(:user, nickname: "robin")

    {:ok, post} =
      CommonAPI.post(batman, %{
        status: "Has anyone seen Selina Kyle's latest selfies?",
        visibility: "private"
      })

    reply = %{
      "type" => "Create",
      "actor" => robin.ap_id,
      "to" => [batman.ap_id, robin.follower_address],
      "cc" => [],
      "object" => %{
        "type" => "Note",
        "actor" => robin.ap_id,
        "content" => "@batman 🤤 ❤️ 🐈‍⬛",
        "to" => [batman.ap_id, robin.follower_address],
        "cc" => [],
        "inReplyTo" => Object.normalize(post).data["id"]
      }
    }

    expected_to = [batman.ap_id]
    expected_cc = []

    assert {:ok, filtered} = FODirectReply.filter(reply)

    assert expected_to == filtered["to"]
    assert expected_cc == filtered["cc"]
    assert expected_to == filtered["object"]["to"]
    assert expected_cc == filtered["object"]["cc"]
  end

  test "replies to unlisted posts are unmodified" do
    batman = insert(:user, nickname: "batman")
    robin = insert(:user, nickname: "robin")

    {:ok, post} =
      CommonAPI.post(batman, %{
        status: "Has anyone seen Selina Kyle's latest selfies?",
        visibility: "unlisted"
      })

    reply = %{
      "type" => "Create",
      "actor" => robin.ap_id,
      "to" => [batman.ap_id, robin.follower_address],
      "cc" => [],
      "object" => %{
        "type" => "Note",
        "actor" => robin.ap_id,
        "content" => "@batman 🤤 ❤️ 🐈<200d>⬛",
        "to" => [batman.ap_id, robin.follower_address],
        "cc" => [],
        "inReplyTo" => Object.normalize(post).data["id"]
      }
    }

    assert {:ok, filtered} = FODirectReply.filter(reply)

    assert match?(^filtered, reply)
  end

  test "replies to public posts are unmodified" do
    batman = insert(:user, nickname: "batman")
    robin = insert(:user, nickname: "robin")

    {:ok, post} =
      CommonAPI.post(batman, %{status: "Has anyone seen Selina Kyle's latest selfies?"})

    reply = %{
      "type" => "Create",
      "actor" => robin.ap_id,
      "to" => [batman.ap_id, robin.follower_address],
      "cc" => [],
      "object" => %{
        "type" => "Note",
        "actor" => robin.ap_id,
        "content" => "@batman 🤤 ❤️ 🐈<200d>⬛",
        "to" => [batman.ap_id, robin.follower_address],
        "cc" => [],
        "inReplyTo" => Object.normalize(post).data["id"]
      }
    }

    assert {:ok, filtered} = FODirectReply.filter(reply)

    assert match?(^filtered, reply)
  end

  test "non-reply posts are unmodified" do
    batman = insert(:user, nickname: "batman")

    {:ok, post} = CommonAPI.post(batman, %{status: "To the Batmobile!"})

    assert {:ok, filtered} = FODirectReply.filter(post)

    assert match?(^filtered, post)
  end
end
