# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.QuietReplyTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  require Pleroma.Constants

  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.MRF.QuietReply
  alias Pleroma.Web.CommonAPI

  test "replying to public post is forced to be quiet" do
    batman = insert(:user, nickname: "batman")
    robin = insert(:user, nickname: "robin")

    {:ok, post} = CommonAPI.post(batman, %{status: "To the Batmobile!"})

    reply = %{
      "type" => "Create",
      "actor" => robin.ap_id,
      "to" => [
        batman.ap_id,
        Pleroma.Constants.as_public()
      ],
      "cc" => [robin.follower_address],
      "object" => %{
        "type" => "Note",
        "actor" => robin.ap_id,
        "content" => "@batman Wait up, I forgot my spandex!",
        "to" => [
          batman.ap_id,
          Pleroma.Constants.as_public()
        ],
        "cc" => [robin.follower_address],
        "inReplyTo" => Object.normalize(post).data["id"]
      }
    }

    expected_to = [batman.ap_id, robin.follower_address]
    expected_cc = [Pleroma.Constants.as_public()]

    assert {:ok, filtered} = QuietReply.filter(reply)

    assert expected_to == filtered["to"]
    assert expected_cc == filtered["cc"]
    assert expected_to == filtered["object"]["to"]
    assert expected_cc == filtered["object"]["cc"]
  end

  test "replying to unlisted post is unmodified" do
    batman = insert(:user, nickname: "batman")
    robin = insert(:user, nickname: "robin")

    {:ok, post} = CommonAPI.post(batman, %{status: "To the Batmobile!", visibility: "private"})

    reply = %{
      "type" => "Create",
      "actor" => robin.ap_id,
      "to" => [batman.ap_id],
      "cc" => [],
      "object" => %{
        "type" => "Note",
        "actor" => robin.ap_id,
        "content" => "@batman Wait up, I forgot my spandex!",
        "to" => [batman.ap_id],
        "cc" => [],
        "inReplyTo" => Object.normalize(post).data["id"]
      }
    }

    assert {:ok, filtered} = QuietReply.filter(reply)

    assert match?(^filtered, reply)
  end

  test "replying direct is unmodified" do
    batman = insert(:user, nickname: "batman")
    robin = insert(:user, nickname: "robin")

    {:ok, post} = CommonAPI.post(batman, %{status: "To the Batmobile!"})

    reply = %{
      "type" => "Create",
      "actor" => robin.ap_id,
      "to" => [batman.ap_id],
      "cc" => [],
      "object" => %{
        "type" => "Note",
        "actor" => robin.ap_id,
        "content" => "@batman Wait up, I forgot my spandex!",
        "to" => [batman.ap_id],
        "cc" => [],
        "inReplyTo" => Object.normalize(post).data["id"]
      }
    }

    assert {:ok, filtered} = QuietReply.filter(reply)

    assert match?(^filtered, reply)
  end

  test "replying followers-only is unmodified" do
    batman = insert(:user, nickname: "batman")
    robin = insert(:user, nickname: "robin")

    {:ok, post} = CommonAPI.post(batman, %{status: "To the Batmobile!"})

    reply = %{
      "type" => "Create",
      "actor" => robin.ap_id,
      "to" => [batman.ap_id, robin.follower_address],
      "cc" => [],
      "object" => %{
        "type" => "Note",
        "actor" => robin.ap_id,
        "content" => "@batman Wait up, I forgot my spandex!",
        "to" => [batman.ap_id, robin.follower_address],
        "cc" => [],
        "inReplyTo" => Object.normalize(post).data["id"]
      }
    }

    assert {:ok, filtered} = QuietReply.filter(reply)

    assert match?(^filtered, reply)
  end

  test "non-reply posts are unmodified" do
    batman = insert(:user, nickname: "batman")

    {:ok, post} = CommonAPI.post(batman, %{status: "To the Batmobile!"})

    assert {:ok, filtered} = QuietReply.filter(post)

    assert match?(^filtered, post)
  end
end
