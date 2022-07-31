# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.UserTest do
  alias Pleroma.Activity
  alias Pleroma.MFA
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.OAuth.Authorization
  alias Pleroma.Web.OAuth.Token

  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  import ExUnit.CaptureIO
  import Mock
  import Pleroma.Factory

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
      send(self(), {:mix_shell_input, :prompt, "Y"})

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

      assert_received {:mix_shell, :prompt, [message]}
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
      send(self(), {:mix_shell_input, :prompt, "N"})

      Mix.Tasks.Pleroma.User.run(["new", unsaved.nickname, unsaved.email])

      assert_received {:mix_shell, :info, [message]}
      assert message =~ "user will be created"

      assert_received {:mix_shell, :prompt, [message]}
      assert message =~ "Continue"

      assert_received {:mix_shell, :info, [message]}
      assert message =~ "will not be created"

      refute User.get_cached_by_nickname(unsaved.nickname)
    end
  end

  describe "running rm" do
    test "user is deleted" do
      clear_config([:instance, :federating], true)
      user = insert(:user)

      with_mock Pleroma.Web.Federator,
        publish: fn _ -> nil end do
        Mix.Tasks.Pleroma.User.run(["rm", user.nickname])
        ObanHelpers.perform_all()

        assert_received {:mix_shell, :info, [message]}
        assert message =~ " deleted"
        assert %{is_active: false} = User.get_by_nickname(user.nickname)

        assert called(Pleroma.Web.Federator.publish(:_))
      end
    end

    test "a remote user's create activity is deleted when the object has been pruned" do
      user = insert(:user)
      user2 = insert(:user)

      {:ok, post} = CommonAPI.post(user, %{status: "uguu"})
      {:ok, post2} = CommonAPI.post(user2, %{status: "test"})
      obj = Object.normalize(post2, fetch: false)

      {:ok, like_object, meta} = Pleroma.Web.ActivityPub.Builder.like(user, obj)

      {:ok, like_activity, _meta} =
        Pleroma.Web.ActivityPub.Pipeline.common_pipeline(
          like_object,
          Keyword.put(meta, :local, true)
        )

      like_activity.data["object"]
      |> Pleroma.Object.get_by_ap_id()
      |> Repo.delete()

      clear_config([:instance, :federating], true)

      object = Object.normalize(post, fetch: false)
      Object.prune(object)

      with_mock Pleroma.Web.Federator,
        publish: fn _ -> nil end do
        Mix.Tasks.Pleroma.User.run(["rm", user.nickname])
        ObanHelpers.perform_all()

        assert_received {:mix_shell, :info, [message]}
        assert message =~ " deleted"
        assert %{is_active: false} = User.get_by_nickname(user.nickname)

        assert called(Pleroma.Web.Federator.publish(:_))
        refute Pleroma.Repo.get(Pleroma.Activity, like_activity.id)
      end

      refute Activity.get_by_id(post.id)
    end

    test "no user to delete" do
      Mix.Tasks.Pleroma.User.run(["rm", "nonexistent"])

      assert_received {:mix_shell, :error, [message]}
      assert message =~ "No local user"
    end
  end

  describe "running deactivate" do
    test "active user is deactivated and unsubscribed" do
      followed = insert(:user)
      remote_followed = insert(:user, local: false)
      user = insert(:user)

      User.follow(user, followed, :follow_accept)
      User.follow(user, remote_followed, :follow_accept)

      Mix.Tasks.Pleroma.User.run(["deactivate", user.nickname])

      # Note that the task has delay :timer.sleep(500)
      assert_received {:mix_shell, :info, [message]}

      assert message ==
               "Successfully deactivated #{user.nickname} and unsubscribed all local followers"

      user = User.get_cached_by_nickname(user.nickname)
      assert Enum.empty?(Enum.filter(User.get_friends(user), & &1.local))
      refute user.is_active
    end

    test "user is deactivated" do
      %{id: id, nickname: nickname} = insert(:user, is_active: false)

      assert :ok = Mix.Tasks.Pleroma.User.run(["deactivate", nickname])
      assert_received {:mix_shell, :info, [message]}
      assert message == "User #{nickname} already deactivated"

      user = Repo.get(User, id)
      refute user.is_active
    end

    test "no user to deactivate" do
      Mix.Tasks.Pleroma.User.run(["deactivate", "nonexistent"])

      assert_received {:mix_shell, :error, [message]}
      assert message =~ "No user"
    end
  end

  describe "running set" do
    test "All statuses set" do
      user = insert(:user)

      Mix.Tasks.Pleroma.User.run([
        "set",
        user.nickname,
        "--admin",
        "--confirmed",
        "--locked",
        "--moderator"
      ])

      assert_received {:mix_shell, :info, [message]}
      assert message =~ ~r/Admin status .* true/

      assert_received {:mix_shell, :info, [message]}
      assert message =~ ~r/Confirmation status.* true/

      assert_received {:mix_shell, :info, [message]}
      assert message =~ ~r/Locked status .* true/

      assert_received {:mix_shell, :info, [message]}
      assert message =~ ~r/Moderator status .* true/

      user = User.get_cached_by_nickname(user.nickname)
      assert user.is_moderator
      assert user.is_locked
      assert user.is_admin
      assert user.is_confirmed
    end

    test "All statuses unset" do
      user =
        insert(:user,
          is_locked: true,
          is_moderator: true,
          is_admin: true,
          is_confirmed: false
        )

      Mix.Tasks.Pleroma.User.run([
        "set",
        user.nickname,
        "--no-admin",
        "--no-confirmed",
        "--no-locked",
        "--no-moderator"
      ])

      assert_received {:mix_shell, :info, [message]}
      assert message =~ ~r/Admin status .* false/

      assert_received {:mix_shell, :info, [message]}
      assert message =~ ~r/Confirmation status.* false/

      assert_received {:mix_shell, :info, [message]}
      assert message =~ ~r/Locked status .* false/

      assert_received {:mix_shell, :info, [message]}
      assert message =~ ~r/Moderator status .* false/

      user = User.get_cached_by_nickname(user.nickname)
      refute user.is_moderator
      refute user.is_locked
      refute user.is_admin
      refute user.is_confirmed
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

  describe "running reset_mfa" do
    test "disables MFA" do
      user =
        insert(:user,
          multi_factor_authentication_settings: %MFA.Settings{
            enabled: true,
            totp: %MFA.Settings.TOTP{secret: "xx", confirmed: true}
          }
        )

      Mix.Tasks.Pleroma.User.run(["reset_mfa", user.nickname])

      assert_received {:mix_shell, :info, [message]}
      assert message == "Multi-Factor Authentication disabled for #{user.nickname}"

      assert %{enabled: false, totp: false} ==
               user.nickname
               |> User.get_cached_by_nickname()
               |> MFA.mfa_settings()
    end

    test "no user to reset MFA" do
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

  describe "running confirm" do
    test "user is confirmed" do
      %{id: id, nickname: nickname} = insert(:user, is_confirmed: true)

      assert :ok = Mix.Tasks.Pleroma.User.run(["confirm", nickname])
      assert_received {:mix_shell, :info, [message]}
      assert message == "#{nickname} doesn't need confirmation."

      user = Repo.get(User, id)
      assert user.is_confirmed
      refute user.confirmation_token
    end

    test "user is not confirmed" do
      %{id: id, nickname: nickname} =
        insert(:user, is_confirmed: false, confirmation_token: "some token")

      assert :ok = Mix.Tasks.Pleroma.User.run(["confirm", nickname])
      assert_received {:mix_shell, :info, [message]}
      assert message == "#{nickname} doesn't need confirmation."

      user = Repo.get(User, id)
      assert user.is_confirmed
      refute user.confirmation_token
    end

    test "it prints an error message when user is not exist" do
      Mix.Tasks.Pleroma.User.run(["confirm", "foo"])

      assert_received {:mix_shell, :error, [message]}
      assert message =~ "No local user"
    end
  end

  describe "running activate" do
    test "user is activated" do
      %{id: id, nickname: nickname} = insert(:user, is_active: true)

      assert :ok = Mix.Tasks.Pleroma.User.run(["activate", nickname])
      assert_received {:mix_shell, :info, [message]}
      assert message == "User #{nickname} already activated"

      user = Repo.get(User, id)
      assert user.is_active
    end

    test "user is not activated" do
      %{id: id, nickname: nickname} = insert(:user, is_active: false)

      assert :ok = Mix.Tasks.Pleroma.User.run(["activate", nickname])
      assert_received {:mix_shell, :info, [message]}
      assert message == "Successfully activated #{nickname}"

      user = Repo.get(User, id)
      assert user.is_active
    end

    test "no user to activate" do
      Mix.Tasks.Pleroma.User.run(["activate", "foo"])

      assert_received {:mix_shell, :error, [message]}
      assert message =~ "No user"
    end
  end

  describe "search" do
    test "it returns users matching" do
      user = insert(:user)
      moon = insert(:user, nickname: "moon", name: "fediverse expert moon")
      moot = insert(:user, nickname: "moot")
      kawen = insert(:user, nickname: "kawen", name: "fediverse expert moon")

      {:ok, user, moon} = User.follow(user, moon)

      assert [moon.id, kawen.id] == User.Search.search("moon") |> Enum.map(& &1.id)

      res = User.search("moo") |> Enum.map(& &1.id)
      assert Enum.sort([moon.id, moot.id, kawen.id]) == Enum.sort(res)

      assert [kawen.id, moon.id] == User.Search.search("expert fediverse") |> Enum.map(& &1.id)

      assert [moon.id, kawen.id] ==
               User.Search.search("expert fediverse", for_user: user) |> Enum.map(& &1.id)
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

  describe "bulk confirm and unconfirm" do
    test "confirm all" do
      user1 = insert(:user, is_confirmed: false)
      user2 = insert(:user, is_confirmed: false)

      refute user1.is_confirmed
      refute user2.is_confirmed

      Mix.Tasks.Pleroma.User.run(["confirm_all"])

      user1 = User.get_cached_by_nickname(user1.nickname)
      user2 = User.get_cached_by_nickname(user2.nickname)

      assert user1.is_confirmed
      assert user2.is_confirmed
    end

    test "unconfirm all" do
      user1 = insert(:user, is_confirmed: true)
      user2 = insert(:user, is_confirmed: true)
      admin = insert(:user, is_admin: true, is_confirmed: true)
      mod = insert(:user, is_moderator: true, is_confirmed: true)

      assert user1.is_confirmed
      assert user2.is_confirmed

      Mix.Tasks.Pleroma.User.run(["unconfirm_all"])

      user1 = User.get_cached_by_nickname(user1.nickname)
      user2 = User.get_cached_by_nickname(user2.nickname)
      admin = User.get_cached_by_nickname(admin.nickname)
      mod = User.get_cached_by_nickname(mod.nickname)

      refute user1.is_confirmed
      refute user2.is_confirmed
      assert admin.is_confirmed
      assert mod.is_confirmed
    end
  end
end
