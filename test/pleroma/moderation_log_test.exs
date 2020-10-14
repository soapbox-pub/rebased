# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ModerationLogTest do
  alias Pleroma.Activity
  alias Pleroma.ModerationLog

  use Pleroma.DataCase

  import Pleroma.Factory

  describe "user moderation" do
    setup do
      admin = insert(:user, is_admin: true)
      moderator = insert(:user, is_moderator: true)
      subject1 = insert(:user)
      subject2 = insert(:user)

      [admin: admin, moderator: moderator, subject1: subject1, subject2: subject2]
    end

    test "logging user deletion by moderator", %{moderator: moderator, subject1: subject1} do
      {:ok, _} =
        ModerationLog.insert_log(%{
          actor: moderator,
          subject: [subject1],
          action: "delete"
        })

      log = Repo.one(ModerationLog)

      assert log.data["message"] == "@#{moderator.nickname} deleted users: @#{subject1.nickname}"
    end

    test "logging user creation by moderator", %{
      moderator: moderator,
      subject1: subject1,
      subject2: subject2
    } do
      {:ok, _} =
        ModerationLog.insert_log(%{
          actor: moderator,
          subjects: [subject1, subject2],
          action: "create"
        })

      log = Repo.one(ModerationLog)

      assert log.data["message"] ==
               "@#{moderator.nickname} created users: @#{subject1.nickname}, @#{subject2.nickname}"
    end

    test "logging user follow by admin", %{admin: admin, subject1: subject1, subject2: subject2} do
      {:ok, _} =
        ModerationLog.insert_log(%{
          actor: admin,
          followed: subject1,
          follower: subject2,
          action: "follow"
        })

      log = Repo.one(ModerationLog)

      assert log.data["message"] ==
               "@#{admin.nickname} made @#{subject2.nickname} follow @#{subject1.nickname}"
    end

    test "logging user unfollow by admin", %{admin: admin, subject1: subject1, subject2: subject2} do
      {:ok, _} =
        ModerationLog.insert_log(%{
          actor: admin,
          followed: subject1,
          follower: subject2,
          action: "unfollow"
        })

      log = Repo.one(ModerationLog)

      assert log.data["message"] ==
               "@#{admin.nickname} made @#{subject2.nickname} unfollow @#{subject1.nickname}"
    end

    test "logging user tagged by admin", %{admin: admin, subject1: subject1, subject2: subject2} do
      {:ok, _} =
        ModerationLog.insert_log(%{
          actor: admin,
          nicknames: [subject1.nickname, subject2.nickname],
          tags: ["foo", "bar"],
          action: "tag"
        })

      log = Repo.one(ModerationLog)

      users =
        [subject1.nickname, subject2.nickname]
        |> Enum.map(&"@#{&1}")
        |> Enum.join(", ")

      tags = ["foo", "bar"] |> Enum.join(", ")

      assert log.data["message"] == "@#{admin.nickname} added tags: #{tags} to users: #{users}"
    end

    test "logging user untagged by admin", %{admin: admin, subject1: subject1, subject2: subject2} do
      {:ok, _} =
        ModerationLog.insert_log(%{
          actor: admin,
          nicknames: [subject1.nickname, subject2.nickname],
          tags: ["foo", "bar"],
          action: "untag"
        })

      log = Repo.one(ModerationLog)

      users =
        [subject1.nickname, subject2.nickname]
        |> Enum.map(&"@#{&1}")
        |> Enum.join(", ")

      tags = ["foo", "bar"] |> Enum.join(", ")

      assert log.data["message"] ==
               "@#{admin.nickname} removed tags: #{tags} from users: #{users}"
    end

    test "logging user grant by moderator", %{moderator: moderator, subject1: subject1} do
      {:ok, _} =
        ModerationLog.insert_log(%{
          actor: moderator,
          subject: [subject1],
          action: "grant",
          permission: "moderator"
        })

      log = Repo.one(ModerationLog)

      assert log.data["message"] == "@#{moderator.nickname} made @#{subject1.nickname} moderator"
    end

    test "logging user revoke by moderator", %{moderator: moderator, subject1: subject1} do
      {:ok, _} =
        ModerationLog.insert_log(%{
          actor: moderator,
          subject: [subject1],
          action: "revoke",
          permission: "moderator"
        })

      log = Repo.one(ModerationLog)

      assert log.data["message"] ==
               "@#{moderator.nickname} revoked moderator role from @#{subject1.nickname}"
    end

    test "logging relay follow", %{moderator: moderator} do
      {:ok, _} =
        ModerationLog.insert_log(%{
          actor: moderator,
          action: "relay_follow",
          target: "https://example.org/relay"
        })

      log = Repo.one(ModerationLog)

      assert log.data["message"] ==
               "@#{moderator.nickname} followed relay: https://example.org/relay"
    end

    test "logging relay unfollow", %{moderator: moderator} do
      {:ok, _} =
        ModerationLog.insert_log(%{
          actor: moderator,
          action: "relay_unfollow",
          target: "https://example.org/relay"
        })

      log = Repo.one(ModerationLog)

      assert log.data["message"] ==
               "@#{moderator.nickname} unfollowed relay: https://example.org/relay"
    end

    test "logging report update", %{moderator: moderator} do
      report = %Activity{
        id: "9m9I1F4p8ftrTP6QTI",
        data: %{
          "type" => "Flag",
          "state" => "resolved"
        }
      }

      {:ok, _} =
        ModerationLog.insert_log(%{
          actor: moderator,
          action: "report_update",
          subject: report
        })

      log = Repo.one(ModerationLog)

      assert log.data["message"] ==
               "@#{moderator.nickname} updated report ##{report.id} with 'resolved' state"
    end

    test "logging report response", %{moderator: moderator} do
      report = %Activity{
        id: "9m9I1F4p8ftrTP6QTI",
        data: %{
          "type" => "Note"
        }
      }

      {:ok, _} =
        ModerationLog.insert_log(%{
          actor: moderator,
          action: "report_note",
          subject: report,
          text: "look at this"
        })

      log = Repo.one(ModerationLog)

      assert log.data["message"] ==
               "@#{moderator.nickname} added note 'look at this' to report ##{report.id}"
    end

    test "logging status sensitivity update", %{moderator: moderator} do
      note = insert(:note_activity)

      {:ok, _} =
        ModerationLog.insert_log(%{
          actor: moderator,
          action: "status_update",
          subject: note,
          sensitive: "true",
          visibility: nil
        })

      log = Repo.one(ModerationLog)

      assert log.data["message"] ==
               "@#{moderator.nickname} updated status ##{note.id}, set sensitive: 'true'"
    end

    test "logging status visibility update", %{moderator: moderator} do
      note = insert(:note_activity)

      {:ok, _} =
        ModerationLog.insert_log(%{
          actor: moderator,
          action: "status_update",
          subject: note,
          sensitive: nil,
          visibility: "private"
        })

      log = Repo.one(ModerationLog)

      assert log.data["message"] ==
               "@#{moderator.nickname} updated status ##{note.id}, set visibility: 'private'"
    end

    test "logging status sensitivity & visibility update", %{moderator: moderator} do
      note = insert(:note_activity)

      {:ok, _} =
        ModerationLog.insert_log(%{
          actor: moderator,
          action: "status_update",
          subject: note,
          sensitive: "true",
          visibility: "private"
        })

      log = Repo.one(ModerationLog)

      assert log.data["message"] ==
               "@#{moderator.nickname} updated status ##{note.id}, set sensitive: 'true', visibility: 'private'"
    end

    test "logging status deletion", %{moderator: moderator} do
      note = insert(:note_activity)

      {:ok, _} =
        ModerationLog.insert_log(%{
          actor: moderator,
          action: "status_delete",
          subject_id: note.id
        })

      log = Repo.one(ModerationLog)

      assert log.data["message"] == "@#{moderator.nickname} deleted status ##{note.id}"
    end
  end
end
