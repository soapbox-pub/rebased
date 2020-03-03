# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.UserTest do
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.OAuth.Authorization
  alias Pleroma.Web.OAuth.Token

  use Pleroma.DataCase

  import Pleroma.Factory
  import ExUnit.CaptureIO

  setup_all do
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)
    end)

    :ok
  end

  describe "running new" do
    test "user is created" do
      # just get random data
      unsaved = build(:user)

      # prepare to answer yes
      send(self(), {:mix_shell_input, :yes?, true})

      Mix.Tasks.Pleroma.User.run([
        "new",
        unsaved.nickname,
        unsaved.email,
        "--name",
        unsaved.name,
        "--bio",
        unsaved.bio,
        "--password",
        "test",
        "--moderator",
        "--admin"
      ])

      assert_received {:mix_shell, :info, [message]}
      assert message =~ "user will be created"

      assert_received {:mix_shell, :yes?, [message]}
      assert message =~ "Continue"

      assert_received {:mix_shell, :info, [message]}
      assert message =~ "created"

      user = User.get_cached_by_nickname(unsaved.nickname)
      assert user.name == unsaved.name
      assert user.email == unsaved.email
      assert user.bio == unsaved.bio
      assert user.is_moderator
      assert user.is_admin
    end

    test "user is not created" do
      unsaved = build(:user)

      # prepare to answer no
      send(self(), {:mix_shell_input, :yes?, false})

      Mix.Tasks.Pleroma.User.run(["new", unsaved.nickname, unsaved.email])

      assert_received {:mix_shell, :info, [message]}
      assert message =~ "user will be created"

      assert_received {:mix_shell, :yes?, [message]}
      assert message =~ "Continue"

      assert_received {:mix_shell, :info, [message]}
      assert message =~ "will not be created"

      refute User.get_cached_by_nickname(unsaved.nickname)
    end
  end

  describe "running rm" do
    test "user is deleted" do
      user = insert(:user)

      Mix.Tasks.Pleroma.User.run(["rm", user.nickname])

      assert_received {:mix_shell, :info, [message]}
      assert message =~ " deleted"

      refute User.get_by_nickname(user.nickname)
    end

    test "no user to delete" do
      Mix.Tasks.Pleroma.User.run(["rm", "nonexistent"])

      assert_received {:mix_shell, :error, [message]}
      assert message =~ "No local user"
    end
  end

  describe "running toggle_activated" do
    test "user is deactivated" do
      user = insert(:user)

      Mix.Tasks.Pleroma.User.run(["toggle_activated", user.nickname])

      assert_received {:mix_shell, :info, [message]}
      assert message =~ " deactivated"

      user = User.get_cached_by_nickname(user.nickname)
      assert user.deactivated
    end

    test "user is activated" do
      user = insert(:user, deactivated: true)

      Mix.Tasks.Pleroma.User.run(["toggle_activated", user.nickname])

      assert_received {:mix_shell, :info, [message]}
      assert message =~ " activated"

      user = User.get_cached_by_nickname(user.nickname)
      refute user.deactivated
    end

    test "no user to toggle" do
      Mix.Tasks.Pleroma.User.run(["toggle_activated", "nonexistent"])

      assert_received {:mix_shell, :error, [message]}
      assert message =~ "No user"
    end
  end

  describe "running unsubscribe" do
    test "user is unsubscribed" do
      followed = insert(:user)
      user = insert(:user)
      User.follow(user, followed, "accept")

      Mix.Tasks.Pleroma.User.run(["unsubscribe", user.nickname])

      assert_received {:mix_shell, :info, [message]}
      assert message =~ "Deactivating"

      assert_received {:mix_shell, :info, [message]}
      assert message =~ "Unsubscribing"

      # Note that the task has delay :timer.sleep(500)
      assert_received {:mix_shell, :info, [message]}
      assert message =~ "Successfully unsubscribed"

      user = User.get_cached_by_nickname(user.nickname)
      assert Enum.empty?(User.get_friends(user))
      assert user.deactivated
    end

    test "no user to unsubscribe" do
      Mix.Tasks.Pleroma.User.run(["unsubscribe", "nonexistent"])

      assert_received {:mix_shell, :error, [message]}
      assert message =~ "No user"
    end
  end

  describe "running set" do
    test "All statuses set" do
      user = insert(:user)

      Mix.Tasks.Pleroma.User.run(["set", user.nickname, "--moderator", "--admin", "--locked"])

      assert_received {:mix_shell, :info, [message]}
      assert message =~ ~r/Moderator status .* true/

      assert_received {:mix_shell, :info, [message]}
      assert message =~ ~r/Locked status .* true/

      assert_received {:mix_shell, :info, [message]}
      assert message =~ ~r/Admin status .* true/

      user = User.get_cached_by_nickname(user.nickname)
      assert user.is_moderator
      assert user.locked
      assert user.is_admin
    end

    test "All statuses unset" do
      user = insert(:user, locked: true, is_moderator: true, is_admin: true)

      Mix.Tasks.Pleroma.User.run([
        "set",
        user.nickname,
        "--no-moderator",
        "--no-admin",
        "--no-locked"
      ])

      assert_received {:mix_shell, :info, [message]}
      assert message =~ ~r/Moderator status .* false/

      assert_received {:mix_shell, :info, [message]}
      assert message =~ ~r/Locked status .* false/

      assert_received {:mix_shell, :info, [message]}
      assert message =~ ~r/Admin status .* false/

      user = User.get_cached_by_nickname(user.nickname)
      refute user.is_moderator
      refute user.locked
      refute user.is_admin
    end

    test "no user to set status" do
      Mix.Tasks.Pleroma.User.run(["set", "nonexistent", "--moderator"])

      assert_received {:mix_shell, :error, [message]}
      assert message =~ "No local user"
    end
  end

  describe "running reset_password" do
    test "password reset token is generated" do
      user = insert(:user)

      assert capture_io(fn ->
               Mix.Tasks.Pleroma.User.run(["reset_password", user.nickname])
             end) =~ "URL:"

      assert_received {:mix_shell, :info, [message]}
      assert message =~ "Generated"
    end

    test "no user to reset password" do
      Mix.Tasks.Pleroma.User.run(["reset_password", "nonexistent"])

      assert_received {:mix_shell, :error, [message]}
      assert message =~ "No local user"
    end
  end

  describe "running invite" do
    test "invite token is generated" do
      assert capture_io(fn ->
               Mix.Tasks.Pleroma.User.run(["invite"])
             end) =~ "http"

      assert_received {:mix_shell, :info, [message]}
      assert message =~ "Generated user invite token one time"
    end

    test "token is generated with expires_at" do
      assert capture_io(fn ->
               Mix.Tasks.Pleroma.User.run([
                 "invite",
                 "--expires-at",
                 Date.to_string(Date.utc_today())
               ])
             end)

      assert_received {:mix_shell, :info, [message]}
      assert message =~ "Generated user invite token date limited"
    end

    test "token is generated with max use" do
      assert capture_io(fn ->
               Mix.Tasks.Pleroma.User.run([
                 "invite",
                 "--max-use",
                 "5"
               ])
             end)

      assert_received {:mix_shell, :info, [message]}
      assert message =~ "Generated user invite token reusable"
    end

    test "token is generated with max use and expires date" do
      assert capture_io(fn ->
               Mix.Tasks.Pleroma.User.run([
                 "invite",
                 "--max-use",
                 "5",
                 "--expires-at",
                 Date.to_string(Date.utc_today())
               ])
             end)

      assert_received {:mix_shell, :info, [message]}
      assert message =~ "Generated user invite token reusable date limited"
    end
  end

  describe "running invites" do
    test "invites are listed" do
      {:ok, invite} = Pleroma.UserInviteToken.create_invite()

      {:ok, invite2} =
        Pleroma.UserInviteToken.create_invite(%{expires_at: Date.utc_today(), max_use: 15})

      # assert capture_io(fn ->
      Mix.Tasks.Pleroma.User.run([
        "invites"
      ])

      #  end)

      assert_received {:mix_shell, :info, [message]}
      assert_received {:mix_shell, :info, [message2]}
      assert_received {:mix_shell, :info, [message3]}
      assert message =~ "Invites list:"
      assert message2 =~ invite.invite_type
      assert message3 =~ invite2.invite_type
    end
  end

  describe "running revoke_invite" do
    test "invite is revoked" do
      {:ok, invite} = Pleroma.UserInviteToken.create_invite(%{expires_at: Date.utc_today()})

      assert capture_io(fn ->
               Mix.Tasks.Pleroma.User.run([
                 "revoke_invite",
                 invite.token
               ])
             end)

      assert_received {:mix_shell, :info, [message]}
      assert message =~ "Invite for token #{invite.token} was revoked."
    end

    test "it prints an error message when invite is not exist" do
      Mix.Tasks.Pleroma.User.run(["revoke_invite", "foo"])

      assert_received {:mix_shell, :error, [message]}
      assert message =~ "No invite found"
    end
  end

  describe "running delete_activities" do
    test "activities are deleted" do
      %{nickname: nickname} = insert(:user)

      assert :ok == Mix.Tasks.Pleroma.User.run(["delete_activities", nickname])
      assert_received {:mix_shell, :info, [message]}
      assert message == "User #{nickname} statuses deleted."
    end

    test "it prints an error message when user is not exist" do
      Mix.Tasks.Pleroma.User.run(["delete_activities", "foo"])

      assert_received {:mix_shell, :error, [message]}
      assert message =~ "No local user"
    end
  end

  describe "running toggle_confirmed" do
    test "user is confirmed" do
      %{id: id, nickname: nickname} = insert(:user, confirmation_pending: false)

      assert :ok = Mix.Tasks.Pleroma.User.run(["toggle_confirmed", nickname])
      assert_received {:mix_shell, :info, [message]}
      assert message == "#{nickname} needs confirmation."

      user = Repo.get(User, id)
      assert user.confirmation_pending
      assert user.confirmation_token
    end

    test "user is not confirmed" do
      %{id: id, nickname: nickname} =
        insert(:user, confirmation_pending: true, confirmation_token: "some token")

      assert :ok = Mix.Tasks.Pleroma.User.run(["toggle_confirmed", nickname])
      assert_received {:mix_shell, :info, [message]}
      assert message == "#{nickname} doesn't need confirmation."

      user = Repo.get(User, id)
      refute user.confirmation_pending
      refute user.confirmation_token
    end

    test "it prints an error message when user is not exist" do
      Mix.Tasks.Pleroma.User.run(["toggle_confirmed", "foo"])

      assert_received {:mix_shell, :error, [message]}
      assert message =~ "No local user"
    end
  end

  describe "search" do
    test "it returns users matching" do
      user = insert(:user)
      moon = insert(:user, nickname: "moon", name: "fediverse expert moon")
      moot = insert(:user, nickname: "moot")
      kawen = insert(:user, nickname: "kawen", name: "fediverse expert moon")

      {:ok, user} = User.follow(user, kawen)

      assert [moon.id, kawen.id] == User.Search.search("moon") |> Enum.map(& &1.id)
      res = User.search("moo") |> Enum.map(& &1.id)
      assert moon.id in res
      assert moot.id in res
      assert kawen.id in res
      assert [moon.id, kawen.id] == User.Search.search("moon fediverse") |> Enum.map(& &1.id)

      assert [kawen.id, moon.id] ==
               User.Search.search("moon fediverse", for_user: user) |> Enum.map(& &1.id)
    end
  end

  describe "signing out" do
    test "it deletes all user's tokens and authorizations" do
      user = insert(:user)
      insert(:oauth_token, user: user)
      insert(:oauth_authorization, user: user)

      assert Repo.get_by(Token, user_id: user.id)
      assert Repo.get_by(Authorization, user_id: user.id)

      :ok = Mix.Tasks.Pleroma.User.run(["sign_out", user.nickname])

      refute Repo.get_by(Token, user_id: user.id)
      refute Repo.get_by(Authorization, user_id: user.id)
    end

    test "it prints an error message when user is not exist" do
      Mix.Tasks.Pleroma.User.run(["sign_out", "foo"])

      assert_received {:mix_shell, :error, [message]}
      assert message =~ "No local user"
    end
  end

  describe "tagging" do
    test "it add tags to a user" do
      user = insert(:user)

      :ok = Mix.Tasks.Pleroma.User.run(["tag", user.nickname, "pleroma"])

      user = User.get_cached_by_nickname(user.nickname)
      assert "pleroma" in user.tags
    end

    test "it prints an error message when user is not exist" do
      Mix.Tasks.Pleroma.User.run(["tag", "foo"])

      assert_received {:mix_shell, :error, [message]}
      assert message =~ "Could not change user tags"
    end
  end

  describe "untagging" do
    test "it deletes tags from a user" do
      user = insert(:user, tags: ["pleroma"])
      assert "pleroma" in user.tags

      :ok = Mix.Tasks.Pleroma.User.run(["untag", user.nickname, "pleroma"])

      user = User.get_cached_by_nickname(user.nickname)
      assert Enum.empty?(user.tags)
    end

    test "it prints an error message when user is not exist" do
      Mix.Tasks.Pleroma.User.run(["untag", "foo"])

      assert_received {:mix_shell, :error, [message]}
      assert message =~ "Could not change user tags"
    end
  end
end
