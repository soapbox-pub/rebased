# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.UserTest do
  alias Pleroma.Activity
  alias Pleroma.Builders.UserBuilder
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI

  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory
  import ExUnit.CaptureLog
  import Swoosh.TestAssertions

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  setup do: clear_config([:instance, :account_activation_required])

  describe "service actors" do
    test "returns updated invisible actor" do
      uri = "#{Pleroma.Web.Endpoint.url()}/relay"
      followers_uri = "#{uri}/followers"

      insert(
        :user,
        %{
          nickname: "relay",
          invisible: false,
          local: true,
          ap_id: uri,
          follower_address: followers_uri
        }
      )

      actor = User.get_or_create_service_actor_by_ap_id(uri, "relay")
      assert actor.invisible
    end

    test "returns relay user" do
      uri = "#{Pleroma.Web.Endpoint.url()}/relay"
      followers_uri = "#{uri}/followers"

      assert %User{
               nickname: "relay",
               invisible: true,
               local: true,
               ap_id: ^uri,
               follower_address: ^followers_uri
             } = User.get_or_create_service_actor_by_ap_id(uri, "relay")

      assert capture_log(fn ->
               refute User.get_or_create_service_actor_by_ap_id("/relay", "relay")
             end) =~ "Cannot create service actor:"
    end

    test "returns invisible actor" do
      uri = "#{Pleroma.Web.Endpoint.url()}/internal/fetch-test"
      followers_uri = "#{uri}/followers"
      user = User.get_or_create_service_actor_by_ap_id(uri, "internal.fetch-test")

      assert %User{
               nickname: "internal.fetch-test",
               invisible: true,
               local: true,
               ap_id: ^uri,
               follower_address: ^followers_uri
             } = user

      user2 = User.get_or_create_service_actor_by_ap_id(uri, "internal.fetch-test")
      assert user.id == user2.id
    end
  end

  describe "AP ID user relationships" do
    setup do
      {:ok, user: insert(:user)}
    end

    test "outgoing_relationships_ap_ids/1", %{user: user} do
      rel_types = [:block, :mute, :notification_mute, :reblog_mute, :inverse_subscription]

      ap_ids_by_rel =
        Enum.into(
          rel_types,
          %{},
          fn rel_type ->
            rel_records =
              insert_list(2, :user_relationship, %{source: user, relationship_type: rel_type})

            ap_ids = Enum.map(rel_records, fn rr -> Repo.preload(rr, :target).target.ap_id end)
            {rel_type, Enum.sort(ap_ids)}
          end
        )

      assert ap_ids_by_rel[:block] == Enum.sort(User.blocked_users_ap_ids(user))
      assert ap_ids_by_rel[:block] == Enum.sort(Enum.map(User.blocked_users(user), & &1.ap_id))

      assert ap_ids_by_rel[:mute] == Enum.sort(User.muted_users_ap_ids(user))
      assert ap_ids_by_rel[:mute] == Enum.sort(Enum.map(User.muted_users(user), & &1.ap_id))

      assert ap_ids_by_rel[:notification_mute] ==
               Enum.sort(User.notification_muted_users_ap_ids(user))

      assert ap_ids_by_rel[:notification_mute] ==
               Enum.sort(Enum.map(User.notification_muted_users(user), & &1.ap_id))

      assert ap_ids_by_rel[:reblog_mute] == Enum.sort(User.reblog_muted_users_ap_ids(user))

      assert ap_ids_by_rel[:reblog_mute] ==
               Enum.sort(Enum.map(User.reblog_muted_users(user), & &1.ap_id))

      assert ap_ids_by_rel[:inverse_subscription] == Enum.sort(User.subscriber_users_ap_ids(user))

      assert ap_ids_by_rel[:inverse_subscription] ==
               Enum.sort(Enum.map(User.subscriber_users(user), & &1.ap_id))

      outgoing_relationships_ap_ids = User.outgoing_relationships_ap_ids(user, rel_types)

      assert ap_ids_by_rel ==
               Enum.into(outgoing_relationships_ap_ids, %{}, fn {k, v} -> {k, Enum.sort(v)} end)
    end
  end

  describe "when tags are nil" do
    test "tagging a user" do
      user = insert(:user, %{tags: nil})
      user = User.tag(user, ["cool", "dude"])

      assert "cool" in user.tags
      assert "dude" in user.tags
    end

    test "untagging a user" do
      user = insert(:user, %{tags: nil})
      user = User.untag(user, ["cool", "dude"])

      assert user.tags == []
    end
  end

  test "ap_id returns the activity pub id for the user" do
    user = UserBuilder.build()

    expected_ap_id = "#{Pleroma.Web.Endpoint.url()}/users/#{user.nickname}"

    assert expected_ap_id == User.ap_id(user)
  end

  test "ap_followers returns the followers collection for the user" do
    user = UserBuilder.build()

    expected_followers_collection = "#{User.ap_id(user)}/followers"

    assert expected_followers_collection == User.ap_followers(user)
  end

  test "ap_following returns the following collection for the user" do
    user = UserBuilder.build()

    expected_followers_collection = "#{User.ap_id(user)}/following"

    assert expected_followers_collection == User.ap_following(user)
  end

  test "returns all pending follow requests" do
    unlocked = insert(:user)
    locked = insert(:user, is_locked: true)
    follower = insert(:user)

    CommonAPI.follow(follower, unlocked)
    CommonAPI.follow(follower, locked)

    assert [] = User.get_follow_requests(unlocked)
    assert [activity] = User.get_follow_requests(locked)

    assert activity
  end

  test "doesn't return already accepted or duplicate follow requests" do
    locked = insert(:user, is_locked: true)
    pending_follower = insert(:user)
    accepted_follower = insert(:user)

    CommonAPI.follow(pending_follower, locked)
    CommonAPI.follow(pending_follower, locked)
    CommonAPI.follow(accepted_follower, locked)

    Pleroma.FollowingRelationship.update(accepted_follower, locked, :follow_accept)

    assert [^pending_follower] = User.get_follow_requests(locked)
  end

  test "doesn't return follow requests for deactivated accounts" do
    locked = insert(:user, is_locked: true)
    pending_follower = insert(:user, %{is_active: false})

    CommonAPI.follow(pending_follower, locked)

    refute pending_follower.is_active
    assert [] = User.get_follow_requests(locked)
  end

  test "clears follow requests when requester is blocked" do
    followed = insert(:user, is_locked: true)
    follower = insert(:user)

    CommonAPI.follow(follower, followed)
    assert [_activity] = User.get_follow_requests(followed)

    {:ok, _user_relationship} = User.block(followed, follower)
    assert [] = User.get_follow_requests(followed)
  end

  test "follow_all follows mutliple users" do
    user = insert(:user)
    followed_zero = insert(:user)
    followed_one = insert(:user)
    followed_two = insert(:user)
    blocked = insert(:user)
    not_followed = insert(:user)
    reverse_blocked = insert(:user)

    {:ok, _user_relationship} = User.block(user, blocked)
    {:ok, _user_relationship} = User.block(reverse_blocked, user)

    {:ok, user, followed_zero} = User.follow(user, followed_zero)

    {:ok, user} = User.follow_all(user, [followed_one, followed_two, blocked, reverse_blocked])

    assert User.following?(user, followed_one)
    assert User.following?(user, followed_two)
    assert User.following?(user, followed_zero)
    refute User.following?(user, not_followed)
    refute User.following?(user, blocked)
    refute User.following?(user, reverse_blocked)
  end

  test "follow_all follows mutliple users without duplicating" do
    user = insert(:user)
    followed_zero = insert(:user)
    followed_one = insert(:user)
    followed_two = insert(:user)

    {:ok, user} = User.follow_all(user, [followed_zero, followed_one])
    assert length(User.following(user)) == 3

    {:ok, user} = User.follow_all(user, [followed_one, followed_two])
    assert length(User.following(user)) == 4
  end

  test "follow takes a user and another user" do
    user = insert(:user)
    followed = insert(:user)

    {:ok, user, followed} = User.follow(user, followed)

    user = User.get_cached_by_id(user.id)
    followed = User.get_cached_by_ap_id(followed.ap_id)

    assert followed.follower_count == 1
    assert user.following_count == 1

    assert User.ap_followers(followed) in User.following(user)
  end

  test "can't follow a deactivated users" do
    user = insert(:user)
    followed = insert(:user, %{is_active: false})

    {:error, _} = User.follow(user, followed)
  end

  test "can't follow a user who blocked us" do
    blocker = insert(:user)
    blockee = insert(:user)

    {:ok, _user_relationship} = User.block(blocker, blockee)

    {:error, _} = User.follow(blockee, blocker)
  end

  test "can't subscribe to a user who blocked us" do
    blocker = insert(:user)
    blocked = insert(:user)

    {:ok, _user_relationship} = User.block(blocker, blocked)

    {:error, _} = User.subscribe(blocked, blocker)
  end

  test "local users do not automatically follow local locked accounts" do
    follower = insert(:user, is_locked: true)
    followed = insert(:user, is_locked: true)

    {:ok, follower, followed} = User.maybe_direct_follow(follower, followed)

    refute User.following?(follower, followed)
  end

  describe "unfollow/2" do
    setup do: clear_config([:instance, :external_user_synchronization])

    test "unfollow with syncronizes external user" do
      clear_config([:instance, :external_user_synchronization], true)

      followed =
        insert(:user,
          nickname: "fuser1",
          follower_address: "http://localhost:4001/users/fuser1/followers",
          following_address: "http://localhost:4001/users/fuser1/following",
          ap_id: "http://localhost:4001/users/fuser1"
        )

      user =
        insert(:user, %{
          local: false,
          nickname: "fuser2",
          ap_id: "http://localhost:4001/users/fuser2",
          follower_address: "http://localhost:4001/users/fuser2/followers",
          following_address: "http://localhost:4001/users/fuser2/following"
        })

      {:ok, user, followed} = User.follow(user, followed, :follow_accept)

      {:ok, user, _activity} = User.unfollow(user, followed)

      user = User.get_cached_by_id(user.id)

      assert User.following(user) == []
    end

    test "unfollow takes a user and another user" do
      followed = insert(:user)
      user = insert(:user)

      {:ok, user, followed} = User.follow(user, followed, :follow_accept)

      assert User.following(user) == [user.follower_address, followed.follower_address]

      {:ok, user, _activity} = User.unfollow(user, followed)

      assert User.following(user) == [user.follower_address]
    end

    test "unfollow doesn't unfollow yourself" do
      user = insert(:user)

      {:error, _} = User.unfollow(user, user)

      assert User.following(user) == [user.follower_address]
    end
  end

  test "test if a user is following another user" do
    followed = insert(:user)
    user = insert(:user)
    User.follow(user, followed, :follow_accept)

    assert User.following?(user, followed)
    refute User.following?(followed, user)
  end

  test "fetches correct profile for nickname beginning with number" do
    # Use old-style integer ID to try to reproduce the problem
    user = insert(:user, %{id: 1080})
    user_with_numbers = insert(:user, %{nickname: "#{user.id}garbage"})
    assert user_with_numbers == User.get_cached_by_nickname_or_id(user_with_numbers.nickname)
  end

  describe "user registration" do
    @full_user_data %{
      bio: "A guy",
      name: "my name",
      nickname: "nick",
      password: "test",
      password_confirmation: "test",
      email: "email@example.com"
    }

    setup do: clear_config([:instance, :autofollowed_nicknames])
    setup do: clear_config([:instance, :autofollowing_nicknames])
    setup do: clear_config([:welcome])
    setup do: clear_config([:instance, :account_activation_required])

    test "it autofollows accounts that are set for it" do
      user = insert(:user)
      remote_user = insert(:user, %{local: false})

      clear_config([:instance, :autofollowed_nicknames], [
        user.nickname,
        remote_user.nickname
      ])

      cng = User.register_changeset(%User{}, @full_user_data)

      {:ok, registered_user} = User.register(cng)

      assert User.following?(registered_user, user)
      refute User.following?(registered_user, remote_user)
    end

    test "it adds automatic followers for new registered accounts" do
      user1 = insert(:user)
      user2 = insert(:user)

      clear_config([:instance, :autofollowing_nicknames], [
        user1.nickname,
        user2.nickname
      ])

      cng = User.register_changeset(%User{}, @full_user_data)

      {:ok, registered_user} = User.register(cng)

      assert User.following?(user1, registered_user)
      assert User.following?(user2, registered_user)
    end

    test "it sends a welcome message if it is set" do
      welcome_user = insert(:user)
      clear_config([:welcome, :direct_message, :enabled], true)
      clear_config([:welcome, :direct_message, :sender_nickname], welcome_user.nickname)
      clear_config([:welcome, :direct_message, :message], "Hello, this is a direct message")

      cng = User.register_changeset(%User{}, @full_user_data)
      {:ok, registered_user} = User.register(cng)
      ObanHelpers.perform_all()

      activity = Repo.one(Pleroma.Activity)
      assert registered_user.ap_id in activity.recipients
      assert Object.normalize(activity, fetch: false).data["content"] =~ "direct message"
      assert activity.actor == welcome_user.ap_id
    end

    test "it sends a welcome chat message if it is set" do
      welcome_user = insert(:user)
      clear_config([:welcome, :chat_message, :enabled], true)
      clear_config([:welcome, :chat_message, :sender_nickname], welcome_user.nickname)
      clear_config([:welcome, :chat_message, :message], "Hello, this is a chat message")

      cng = User.register_changeset(%User{}, @full_user_data)
      {:ok, registered_user} = User.register(cng)
      ObanHelpers.perform_all()

      activity = Repo.one(Pleroma.Activity)
      assert registered_user.ap_id in activity.recipients
      assert Object.normalize(activity, fetch: false).data["content"] =~ "chat message"
      assert activity.actor == welcome_user.ap_id
    end

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

    setup do:
            clear_config(:mrf,
              policies: [
                Pleroma.Web.ActivityPub.MRF.SimplePolicy
              ]
            )

    test "it sends a welcome chat message when Simple policy applied to local instance" do
      clear_config([:mrf_simple, :media_nsfw], [{"localhost", ""}])

      welcome_user = insert(:user)
      clear_config([:welcome, :chat_message, :enabled], true)
      clear_config([:welcome, :chat_message, :sender_nickname], welcome_user.nickname)
      clear_config([:welcome, :chat_message, :message], "Hello, this is a chat message")

      cng = User.register_changeset(%User{}, @full_user_data)
      {:ok, registered_user} = User.register(cng)
      ObanHelpers.perform_all()

      activity = Repo.one(Pleroma.Activity)
      assert registered_user.ap_id in activity.recipients
      assert Object.normalize(activity, fetch: false).data["content"] =~ "chat message"
      assert activity.actor == welcome_user.ap_id
    end

    test "it sends a welcome email message if it is set" do
      welcome_user = insert(:user)
      clear_config([:welcome, :email, :enabled], true)
      clear_config([:welcome, :email, :sender], welcome_user.email)

      clear_config(
        [:welcome, :email, :subject],
        "Hello, welcome to cool site: <%= instance_name %>"
      )

      instance_name = Pleroma.Config.get([:instance, :name])

      cng = User.register_changeset(%User{}, @full_user_data)
      {:ok, registered_user} = User.register(cng)
      ObanHelpers.perform_all()

      assert_email_sent(
        from: {instance_name, welcome_user.email},
        to: {registered_user.name, registered_user.email},
        subject: "Hello, welcome to cool site: #{instance_name}",
        html_body: "Welcome to #{instance_name}"
      )
    end

    test "it sends a confirm email" do
      clear_config([:instance, :account_activation_required], true)

      cng = User.register_changeset(%User{}, @full_user_data)
      {:ok, registered_user} = User.register(cng)
      ObanHelpers.perform_all()

      Pleroma.Emails.UserEmail.account_confirmation_email(registered_user)
      # temporary hackney fix until hackney max_connections bug is fixed
      # https://git.pleroma.social/pleroma/pleroma/-/issues/2101
      |> Swoosh.Email.put_private(:hackney_options, ssl_options: [versions: [:"tlsv1.2"]])
      |> assert_email_sent()
    end

    test "sends a pending approval email" do
      clear_config([:instance, :account_approval_required], true)

      {:ok, user} =
        User.register_changeset(%User{}, @full_user_data)
        |> User.register()

      ObanHelpers.perform_all()

      assert_email_sent(
        from: Pleroma.Config.Helpers.sender(),
        to: {user.name, user.email},
        subject: "Your account is awaiting approval"
      )
    end

    test "it sends a registration confirmed email if no others will be sent" do
      clear_config([:welcome, :email, :enabled], false)
      clear_config([:instance, :account_activation_required], false)
      clear_config([:instance, :account_approval_required], false)

      {:ok, user} =
        User.register_changeset(%User{}, @full_user_data)
        |> User.register()

      ObanHelpers.perform_all()

      instance_name = Pleroma.Config.get([:instance, :name])
      sender = Pleroma.Config.get([:instance, :notify_email])

      assert_email_sent(
        from: {instance_name, sender},
        to: {user.name, user.email},
        subject: "Account registered on #{instance_name}"
      )
    end

    test "it fails gracefully with invalid email config" do
      cng = User.register_changeset(%User{}, @full_user_data)

      # Disable the mailer but enable all the things that want to send emails
      clear_config([Pleroma.Emails.Mailer, :enabled], false)
      clear_config([:instance, :account_activation_required], true)
      clear_config([:instance, :account_approval_required], true)
      clear_config([:welcome, :email, :enabled], true)
      clear_config([:welcome, :email, :sender], "lain@lain.com")

      # The user is still created
      assert {:ok, %User{nickname: "nick"}} = User.register(cng)

      # No emails are sent
      ObanHelpers.perform_all()
      refute_email_sent()
    end

    test "it requires an email, name, nickname and password, bio is optional when account_activation_required is enabled" do
      clear_config([:instance, :account_activation_required], true)

      @full_user_data
      |> Map.keys()
      |> Enum.each(fn key ->
        params = Map.delete(@full_user_data, key)
        changeset = User.register_changeset(%User{}, params)

        assert if key == :bio, do: changeset.valid?, else: not changeset.valid?
      end)
    end

    test "it requires an name, nickname and password, bio and email are optional when account_activation_required is disabled" do
      clear_config([:instance, :account_activation_required], false)

      @full_user_data
      |> Map.keys()
      |> Enum.each(fn key ->
        params = Map.delete(@full_user_data, key)
        changeset = User.register_changeset(%User{}, params)

        assert if key in [:bio, :email], do: changeset.valid?, else: not changeset.valid?
      end)
    end

    test "it restricts certain nicknames" do
      [restricted_name | _] = Pleroma.Config.get([User, :restricted_nicknames])

      assert is_bitstring(restricted_name)

      params =
        @full_user_data
        |> Map.put(:nickname, restricted_name)

      changeset = User.register_changeset(%User{}, params)

      refute changeset.valid?
    end

    test "it blocks blacklisted email domains" do
      clear_config([User, :email_blacklist], ["trolling.world"])

      # Block with match
      params = Map.put(@full_user_data, :email, "troll@trolling.world")
      changeset = User.register_changeset(%User{}, params)
      refute changeset.valid?

      # Block with subdomain match
      params = Map.put(@full_user_data, :email, "troll@gnomes.trolling.world")
      changeset = User.register_changeset(%User{}, params)
      refute changeset.valid?

      # Pass with different domains that are similar
      params = Map.put(@full_user_data, :email, "troll@gnomestrolling.world")
      changeset = User.register_changeset(%User{}, params)
      assert changeset.valid?

      params = Map.put(@full_user_data, :email, "troll@trolling.world.us")
      changeset = User.register_changeset(%User{}, params)
      assert changeset.valid?
    end

    test "it sets the password_hash and ap_id" do
      changeset = User.register_changeset(%User{}, @full_user_data)

      assert changeset.valid?

      assert is_binary(changeset.changes[:password_hash])
      assert changeset.changes[:ap_id] == User.ap_id(%User{nickname: @full_user_data.nickname})

      assert changeset.changes.follower_address == "#{changeset.changes.ap_id}/followers"
    end

    test "it sets the 'accepts_chat_messages' set to true" do
      changeset = User.register_changeset(%User{}, @full_user_data)
      assert changeset.valid?

      {:ok, user} = Repo.insert(changeset)

      assert user.accepts_chat_messages
    end

    test "it creates a confirmed user" do
      changeset = User.register_changeset(%User{}, @full_user_data)
      assert changeset.valid?

      {:ok, user} = Repo.insert(changeset)

      assert user.is_confirmed
    end
  end

  describe "user registration, with :account_activation_required" do
    @full_user_data %{
      bio: "A guy",
      name: "my name",
      nickname: "nick",
      password: "test",
      password_confirmation: "test",
      email: "email@example.com"
    }
    setup do: clear_config([:instance, :account_activation_required], true)

    test "it creates unconfirmed user" do
      changeset = User.register_changeset(%User{}, @full_user_data)
      assert changeset.valid?

      {:ok, user} = Repo.insert(changeset)

      refute user.is_confirmed
      assert user.confirmation_token
    end

    test "it creates confirmed user if :confirmed option is given" do
      changeset = User.register_changeset(%User{}, @full_user_data, confirmed: true)
      assert changeset.valid?

      {:ok, user} = Repo.insert(changeset)

      assert user.is_confirmed
      refute user.confirmation_token
    end
  end

  describe "user registration, with :account_approval_required" do
    @full_user_data %{
      bio: "A guy",
      name: "my name",
      nickname: "nick",
      password: "test",
      password_confirmation: "test",
      email: "email@example.com",
      registration_reason: "I'm a cool guy :)"
    }
    setup do: clear_config([:instance, :account_approval_required], true)

    test "it creates unapproved user" do
      changeset = User.register_changeset(%User{}, @full_user_data)
      assert changeset.valid?

      {:ok, user} = Repo.insert(changeset)

      refute user.is_approved
      assert user.registration_reason == "I'm a cool guy :)"
    end

    test "it restricts length of registration reason" do
      reason_limit = Pleroma.Config.get([:instance, :registration_reason_length])

      assert is_integer(reason_limit)

      params =
        @full_user_data
        |> Map.put(
          :registration_reason,
          "Quia et nesciunt dolores numquam ipsam nisi sapiente soluta. Ullam repudiandae nisi quam porro officiis officiis ad. Consequatur animi velit ex quia. Odit voluptatem perferendis quia ut nisi. Dignissimos sit soluta atque aliquid dolorem ut dolorum ut. Labore voluptates iste iusto amet voluptatum earum. Ad fugit illum nam eos ut nemo. Pariatur ea fuga non aspernatur. Dignissimos debitis officia corporis est nisi ab et. Atque itaque alias eius voluptas minus. Accusamus numquam tempore occaecati in."
        )

      changeset = User.register_changeset(%User{}, params)

      refute changeset.valid?
    end
  end

  describe "user registration, with :birthday_required and :birthday_min_age" do
    @full_user_data %{
      bio: "A guy",
      name: "my name",
      nickname: "nick",
      password: "test",
      password_confirmation: "test",
      email: "email@example.com"
    }

    setup do
      clear_config([:instance, :birthday_required], true)
      clear_config([:instance, :birthday_min_age], 18 * 365)
    end

    test "it passes when correct birth date is provided" do
      today = Date.utc_today()
      birthday = Date.add(today, -19 * 365)

      params =
        @full_user_data
        |> Map.put(:birthday, birthday)

      changeset = User.register_changeset(%User{}, params)

      assert changeset.valid?
    end

    test "it fails when birth date is not provided" do
      changeset = User.register_changeset(%User{}, @full_user_data)

      refute changeset.valid?
    end

    test "it fails when provided invalid birth date" do
      today = Date.utc_today()
      birthday = Date.add(today, -17 * 365)

      params =
        @full_user_data
        |> Map.put(:birthday, birthday)

      changeset = User.register_changeset(%User{}, params)

      refute changeset.valid?
    end
  end

  describe "get_or_fetch/1" do
    test "gets an existing user by nickname" do
      user = insert(:user)
      {:ok, fetched_user} = User.get_or_fetch(user.nickname)

      assert user == fetched_user
    end

    test "gets an existing user by ap_id" do
      ap_id = "http://mastodon.example.org/users/admin"

      user =
        insert(
          :user,
          local: false,
          nickname: "admin@mastodon.example.org",
          ap_id: ap_id
        )

      {:ok, fetched_user} = User.get_or_fetch(ap_id)
      freshed_user = refresh_record(user)
      assert freshed_user == fetched_user
    end
  end

  describe "fetching a user from nickname or trying to build one" do
    test "gets an existing user" do
      user = insert(:user)
      {:ok, fetched_user} = User.get_or_fetch_by_nickname(user.nickname)

      assert user == fetched_user
    end

    test "gets an existing user, case insensitive" do
      user = insert(:user, nickname: "nick")
      {:ok, fetched_user} = User.get_or_fetch_by_nickname("NICK")

      assert user == fetched_user
    end

    test "gets an existing user by fully qualified nickname" do
      user = insert(:user)

      {:ok, fetched_user} =
        User.get_or_fetch_by_nickname(user.nickname <> "@" <> Pleroma.Web.Endpoint.host())

      assert user == fetched_user
    end

    test "gets an existing user by fully qualified nickname, case insensitive" do
      user = insert(:user, nickname: "nick")
      casing_altered_fqn = String.upcase(user.nickname <> "@" <> Pleroma.Web.Endpoint.host())

      {:ok, fetched_user} = User.get_or_fetch_by_nickname(casing_altered_fqn)

      assert user == fetched_user
    end

    @tag capture_log: true
    test "returns nil if no user could be fetched" do
      {:error, fetched_user} = User.get_or_fetch_by_nickname("nonexistant@social.heldscal.la")
      assert fetched_user == "not found nonexistant@social.heldscal.la"
    end

    test "returns nil for nonexistant local user" do
      {:error, fetched_user} = User.get_or_fetch_by_nickname("nonexistant")
      assert fetched_user == "not found nonexistant"
    end

    test "updates an existing user, if stale" do
      a_week_ago = NaiveDateTime.add(NaiveDateTime.utc_now(), -604_800)

      orig_user =
        insert(
          :user,
          local: false,
          nickname: "admin@mastodon.example.org",
          ap_id: "http://mastodon.example.org/users/admin",
          last_refreshed_at: a_week_ago
        )

      assert orig_user.last_refreshed_at == a_week_ago

      {:ok, user} = User.get_or_fetch_by_ap_id("http://mastodon.example.org/users/admin")

      assert user.inbox

      refute user.last_refreshed_at == orig_user.last_refreshed_at
    end

    test "if nicknames clash, the old user gets a prefix with the old id to the nickname" do
      a_week_ago = NaiveDateTime.add(NaiveDateTime.utc_now(), -604_800)

      orig_user =
        insert(
          :user,
          local: false,
          nickname: "admin@mastodon.example.org",
          ap_id: "http://mastodon.example.org/users/harinezumigari",
          last_refreshed_at: a_week_ago
        )

      assert orig_user.last_refreshed_at == a_week_ago

      {:ok, user} = User.get_or_fetch_by_ap_id("http://mastodon.example.org/users/admin")

      assert user.inbox

      refute user.id == orig_user.id

      orig_user = User.get_by_id(orig_user.id)

      assert orig_user.nickname == "#{orig_user.id}.admin@mastodon.example.org"
    end

    @tag capture_log: true
    test "it returns the old user if stale, but unfetchable" do
      a_week_ago = NaiveDateTime.add(NaiveDateTime.utc_now(), -604_800)

      orig_user =
        insert(
          :user,
          local: false,
          nickname: "admin@mastodon.example.org",
          ap_id: "http://mastodon.example.org/users/raymoo",
          last_refreshed_at: a_week_ago
        )

      assert orig_user.last_refreshed_at == a_week_ago

      {:ok, user} = User.get_or_fetch_by_ap_id("http://mastodon.example.org/users/raymoo")

      assert user.last_refreshed_at == orig_user.last_refreshed_at
    end
  end

  test "returns an ap_id for a user" do
    user = insert(:user)

    assert User.ap_id(user) ==
             Pleroma.Web.Router.Helpers.user_feed_url(
               Pleroma.Web.Endpoint,
               :feed_redirect,
               user.nickname
             )
  end

  test "returns an ap_followers link for a user" do
    user = insert(:user)

    assert User.ap_followers(user) ==
             Pleroma.Web.Router.Helpers.user_feed_url(
               Pleroma.Web.Endpoint,
               :feed_redirect,
               user.nickname
             ) <> "/followers"
  end

  describe "remote user changeset" do
    @valid_remote %{
      bio: "hello",
      name: "Someone",
      nickname: "a@b.de",
      ap_id: "http...",
      avatar: %{some: "avatar"}
    }
    setup do: clear_config([:instance, :user_bio_length])
    setup do: clear_config([:instance, :user_name_length])

    test "it confirms validity" do
      cs = User.remote_user_changeset(@valid_remote)
      assert cs.valid?
    end

    test "it sets the follower_adress" do
      cs = User.remote_user_changeset(@valid_remote)
      # remote users get a fake local follower address
      assert cs.changes.follower_address ==
               User.ap_followers(%User{nickname: @valid_remote[:nickname]})
    end

    test "it enforces the fqn format for nicknames" do
      cs = User.remote_user_changeset(%{@valid_remote | nickname: "bla"})
      assert Ecto.Changeset.get_field(cs, :local) == false
      assert cs.changes.avatar
      refute cs.valid?
    end

    test "it has required fields" do
      [:ap_id]
      |> Enum.each(fn field ->
        cs = User.remote_user_changeset(Map.delete(@valid_remote, field))
        refute cs.valid?
      end)
    end

    test "it is invalid given a local user" do
      user = insert(:user)
      cs = User.remote_user_changeset(user, %{name: "tom from myspace"})

      refute cs.valid?
    end
  end

  describe "followers and friends" do
    test "gets all followers for a given user" do
      user = insert(:user)
      follower_one = insert(:user)
      follower_two = insert(:user)
      not_follower = insert(:user)

      {:ok, follower_one, user} = User.follow(follower_one, user)
      {:ok, follower_two, user} = User.follow(follower_two, user)

      res = User.get_followers(user)

      assert Enum.member?(res, follower_one)
      assert Enum.member?(res, follower_two)
      refute Enum.member?(res, not_follower)
    end

    test "gets all friends (followed users) for a given user" do
      user = insert(:user)
      followed_one = insert(:user)
      followed_two = insert(:user)
      not_followed = insert(:user)

      {:ok, user, followed_one} = User.follow(user, followed_one)
      {:ok, user, followed_two} = User.follow(user, followed_two)

      res = User.get_friends(user)

      followed_one = User.get_cached_by_ap_id(followed_one.ap_id)
      followed_two = User.get_cached_by_ap_id(followed_two.ap_id)
      assert Enum.member?(res, followed_one)
      assert Enum.member?(res, followed_two)
      refute Enum.member?(res, not_followed)
    end
  end

  describe "updating note and follower count" do
    test "it sets the note_count property" do
      note = insert(:note)

      user = User.get_cached_by_ap_id(note.data["actor"])

      assert user.note_count == 0

      {:ok, user} = User.update_note_count(user)

      assert user.note_count == 1
    end

    test "it increases the note_count property" do
      note = insert(:note)
      user = User.get_cached_by_ap_id(note.data["actor"])

      assert user.note_count == 0

      {:ok, user} = User.increase_note_count(user)

      assert user.note_count == 1

      {:ok, user} = User.increase_note_count(user)

      assert user.note_count == 2
    end

    test "it decreases the note_count property" do
      note = insert(:note)
      user = User.get_cached_by_ap_id(note.data["actor"])

      assert user.note_count == 0

      {:ok, user} = User.increase_note_count(user)

      assert user.note_count == 1

      {:ok, user} = User.decrease_note_count(user)

      assert user.note_count == 0

      {:ok, user} = User.decrease_note_count(user)

      assert user.note_count == 0
    end

    test "it sets the follower_count property" do
      user = insert(:user)
      follower = insert(:user)

      User.follow(follower, user)

      assert user.follower_count == 0

      {:ok, user} = User.update_follower_count(user)

      assert user.follower_count == 1
    end
  end

  describe "mutes" do
    test "it mutes people" do
      user = insert(:user)
      muted_user = insert(:user)

      refute User.mutes?(user, muted_user)
      refute User.muted_notifications?(user, muted_user)

      {:ok, _user_relationships} = User.mute(user, muted_user)

      assert User.mutes?(user, muted_user)
      assert User.muted_notifications?(user, muted_user)
    end

    test "expiring" do
      user = insert(:user)
      muted_user = insert(:user)

      {:ok, _user_relationships} = User.mute(user, muted_user, %{expires_in: 60})
      assert User.mutes?(user, muted_user)

      worker = Pleroma.Workers.MuteExpireWorker
      args = %{"op" => "unmute_user", "muter_id" => user.id, "mutee_id" => muted_user.id}

      assert_enqueued(
        worker: worker,
        args: args
      )

      assert :ok = perform_job(worker, args)

      refute User.mutes?(user, muted_user)
      refute User.muted_notifications?(user, muted_user)
    end

    test "it unmutes users" do
      user = insert(:user)
      muted_user = insert(:user)

      {:ok, _user_relationships} = User.mute(user, muted_user)
      {:ok, _user_mute} = User.unmute(user, muted_user)

      refute User.mutes?(user, muted_user)
      refute User.muted_notifications?(user, muted_user)
    end

    test "it unmutes users by id" do
      user = insert(:user)
      muted_user = insert(:user)

      {:ok, _user_relationships} = User.mute(user, muted_user)
      {:ok, _user_mute} = User.unmute(user.id, muted_user.id)

      refute User.mutes?(user, muted_user)
      refute User.muted_notifications?(user, muted_user)
    end

    test "it mutes user without notifications" do
      user = insert(:user)
      muted_user = insert(:user)

      refute User.mutes?(user, muted_user)
      refute User.muted_notifications?(user, muted_user)

      {:ok, _user_relationships} = User.mute(user, muted_user, %{notifications: false})

      assert User.mutes?(user, muted_user)
      refute User.muted_notifications?(user, muted_user)
    end
  end

  describe "blocks" do
    test "it blocks people" do
      user = insert(:user)
      blocked_user = insert(:user)

      refute User.blocks?(user, blocked_user)

      {:ok, _user_relationship} = User.block(user, blocked_user)

      assert User.blocks?(user, blocked_user)
    end

    test "it unblocks users" do
      user = insert(:user)
      blocked_user = insert(:user)

      {:ok, _user_relationship} = User.block(user, blocked_user)
      {:ok, _user_block} = User.unblock(user, blocked_user)

      refute User.blocks?(user, blocked_user)
    end

    test "blocks tear down cyclical follow relationships" do
      blocker = insert(:user)
      blocked = insert(:user)

      {:ok, blocker, blocked} = User.follow(blocker, blocked)
      {:ok, blocked, blocker} = User.follow(blocked, blocker)

      assert User.following?(blocker, blocked)
      assert User.following?(blocked, blocker)

      {:ok, _user_relationship} = User.block(blocker, blocked)
      blocked = User.get_cached_by_id(blocked.id)

      assert User.blocks?(blocker, blocked)

      refute User.following?(blocker, blocked)
      refute User.following?(blocked, blocker)
    end

    test "blocks tear down blocker->blocked follow relationships" do
      blocker = insert(:user)
      blocked = insert(:user)

      {:ok, blocker, blocked} = User.follow(blocker, blocked)

      assert User.following?(blocker, blocked)
      refute User.following?(blocked, blocker)

      {:ok, _user_relationship} = User.block(blocker, blocked)
      blocked = User.get_cached_by_id(blocked.id)

      assert User.blocks?(blocker, blocked)

      refute User.following?(blocker, blocked)
      refute User.following?(blocked, blocker)
    end

    test "blocks tear down blocked->blocker follow relationships" do
      blocker = insert(:user)
      blocked = insert(:user)

      {:ok, blocked, blocker} = User.follow(blocked, blocker)

      refute User.following?(blocker, blocked)
      assert User.following?(blocked, blocker)

      {:ok, _user_relationship} = User.block(blocker, blocked)
      blocked = User.get_cached_by_id(blocked.id)

      assert User.blocks?(blocker, blocked)

      refute User.following?(blocker, blocked)
      refute User.following?(blocked, blocker)
    end

    test "blocks tear down blocked->blocker subscription relationships" do
      blocker = insert(:user)
      blocked = insert(:user)

      {:ok, _subscription} = User.subscribe(blocked, blocker)

      assert User.subscribed_to?(blocked, blocker)
      refute User.subscribed_to?(blocker, blocked)

      {:ok, _user_relationship} = User.block(blocker, blocked)

      assert User.blocks?(blocker, blocked)
      refute User.subscribed_to?(blocker, blocked)
      refute User.subscribed_to?(blocked, blocker)
    end
  end

  describe "domain blocking" do
    test "blocks domains" do
      user = insert(:user)
      collateral_user = insert(:user, %{ap_id: "https://awful-and-rude-instance.com/user/bully"})

      {:ok, user} = User.block_domain(user, "awful-and-rude-instance.com")

      assert User.blocks?(user, collateral_user)
    end

    test "does not block domain with same end" do
      user = insert(:user)

      collateral_user =
        insert(:user, %{ap_id: "https://another-awful-and-rude-instance.com/user/bully"})

      {:ok, user} = User.block_domain(user, "awful-and-rude-instance.com")

      refute User.blocks?(user, collateral_user)
    end

    test "does not block domain with same end if wildcard added" do
      user = insert(:user)

      collateral_user =
        insert(:user, %{ap_id: "https://another-awful-and-rude-instance.com/user/bully"})

      {:ok, user} = User.block_domain(user, "*.awful-and-rude-instance.com")

      refute User.blocks?(user, collateral_user)
    end

    test "blocks domain with wildcard for subdomain" do
      user = insert(:user)

      user_from_subdomain =
        insert(:user, %{ap_id: "https://subdomain.awful-and-rude-instance.com/user/bully"})

      user_with_two_subdomains =
        insert(:user, %{
          ap_id: "https://subdomain.second_subdomain.awful-and-rude-instance.com/user/bully"
        })

      user_domain = insert(:user, %{ap_id: "https://awful-and-rude-instance.com/user/bully"})

      {:ok, user} = User.block_domain(user, "*.awful-and-rude-instance.com")

      assert User.blocks?(user, user_from_subdomain)
      assert User.blocks?(user, user_with_two_subdomains)
      assert User.blocks?(user, user_domain)
    end

    test "unblocks domains" do
      user = insert(:user)
      collateral_user = insert(:user, %{ap_id: "https://awful-and-rude-instance.com/user/bully"})

      {:ok, user} = User.block_domain(user, "awful-and-rude-instance.com")
      {:ok, user} = User.unblock_domain(user, "awful-and-rude-instance.com")

      refute User.blocks?(user, collateral_user)
    end

    test "follows take precedence over domain blocks" do
      user = insert(:user)
      good_eggo = insert(:user, %{ap_id: "https://meanies.social/user/cuteposter"})

      {:ok, user} = User.block_domain(user, "meanies.social")
      {:ok, user, good_eggo} = User.follow(user, good_eggo)

      refute User.blocks?(user, good_eggo)
    end
  end

  describe "get_recipients_from_activity" do
    test "works for announces" do
      actor = insert(:user)
      user = insert(:user, local: true)

      {:ok, activity} = CommonAPI.post(actor, %{status: "hello"})
      {:ok, announce} = CommonAPI.repeat(activity.id, user)

      recipients = User.get_recipients_from_activity(announce)

      assert user in recipients
    end

    test "get recipients" do
      actor = insert(:user)
      user = insert(:user, local: true)
      user_two = insert(:user, local: false)
      addressed = insert(:user, local: true)
      addressed_remote = insert(:user, local: false)

      {:ok, activity} =
        CommonAPI.post(actor, %{
          status: "hey @#{addressed.nickname} @#{addressed_remote.nickname}"
        })

      assert Enum.map([actor, addressed], & &1.ap_id) --
               Enum.map(User.get_recipients_from_activity(activity), & &1.ap_id) == []

      {:ok, user, actor} = User.follow(user, actor)
      {:ok, _user_two, _actor} = User.follow(user_two, actor)
      recipients = User.get_recipients_from_activity(activity)
      assert length(recipients) == 3
      assert user in recipients
      assert addressed in recipients
    end

    test "has following" do
      actor = insert(:user)
      user = insert(:user)
      user_two = insert(:user)
      addressed = insert(:user, local: true)

      {:ok, activity} =
        CommonAPI.post(actor, %{
          status: "hey @#{addressed.nickname}"
        })

      assert Enum.map([actor, addressed], & &1.ap_id) --
               Enum.map(User.get_recipients_from_activity(activity), & &1.ap_id) == []

      {:ok, _actor, _user} = User.follow(actor, user)
      {:ok, _actor, _user_two} = User.follow(actor, user_two)
      recipients = User.get_recipients_from_activity(activity)
      assert length(recipients) == 2
      assert addressed in recipients
    end
  end

  describe ".set_activation" do
    test "can de-activate then re-activate a user" do
      user = insert(:user)
      assert user.is_active
      {:ok, user} = User.set_activation(user, false)
      refute user.is_active
      {:ok, user} = User.set_activation(user, true)
      assert user.is_active
    end

    test "hide a user from followers" do
      user = insert(:user)
      user2 = insert(:user)

      {:ok, user, user2} = User.follow(user, user2)
      {:ok, _user} = User.set_activation(user, false)

      user2 = User.get_cached_by_id(user2.id)

      assert user2.follower_count == 0
      assert [] = User.get_followers(user2)
    end

    test "hide a user from friends" do
      user = insert(:user)
      user2 = insert(:user)

      {:ok, user2, user} = User.follow(user2, user)
      assert user2.following_count == 1
      assert User.following_count(user2) == 1

      {:ok, _user} = User.set_activation(user, false)

      user2 = User.get_cached_by_id(user2.id)

      assert refresh_record(user2).following_count == 0
      assert user2.following_count == 0
      assert User.following_count(user2) == 0
      assert [] = User.get_friends(user2)
    end

    test "hide a user's statuses from timelines and notifications" do
      user = insert(:user)
      user2 = insert(:user)

      {:ok, user2, user} = User.follow(user2, user)

      {:ok, activity} = CommonAPI.post(user, %{status: "hey @#{user2.nickname}"})

      activity = Repo.preload(activity, :bookmark)

      [notification] = Pleroma.Notification.for_user(user2)
      assert notification.activity.id == activity.id

      assert [activity] == ActivityPub.fetch_public_activities(%{}) |> Repo.preload(:bookmark)

      assert [%{activity | thread_muted?: CommonAPI.thread_muted?(user2, activity)}] ==
               ActivityPub.fetch_activities([user2.ap_id | User.following(user2)], %{
                 user: user2
               })

      {:ok, _user} = User.set_activation(user, false)

      assert [] == ActivityPub.fetch_public_activities(%{})
      assert [] == Pleroma.Notification.for_user(user2)

      assert [] ==
               ActivityPub.fetch_activities([user2.ap_id | User.following(user2)], %{
                 user: user2
               })
    end
  end

  describe "approve" do
    test "approves a user" do
      user = insert(:user, is_approved: false)
      refute user.is_approved
      {:ok, user} = User.approve(user)
      assert user.is_approved
    end

    test "approves a list of users" do
      unapproved_users = [
        insert(:user, is_approved: false),
        insert(:user, is_approved: false),
        insert(:user, is_approved: false)
      ]

      {:ok, users} = User.approve(unapproved_users)

      assert Enum.count(users) == 3

      Enum.each(users, fn user ->
        assert user.is_approved
      end)
    end

    test "it sends welcome email if it is set" do
      clear_config([:welcome, :email, :enabled], true)
      clear_config([:welcome, :email, :sender], "tester@test.me")

      user = insert(:user, is_approved: false)
      welcome_user = insert(:user, email: "tester@test.me")
      instance_name = Pleroma.Config.get([:instance, :name])

      User.approve(user)

      ObanHelpers.perform_all()

      assert_email_sent(
        from: {instance_name, welcome_user.email},
        to: {user.name, user.email},
        html_body: "Welcome to #{instance_name}"
      )
    end

    test "approving an approved user does not trigger post-register actions" do
      clear_config([:welcome, :email, :enabled], true)

      user = insert(:user, is_approved: true)
      User.approve(user)

      ObanHelpers.perform_all()

      assert_no_email_sent()
    end
  end

  describe "confirm" do
    test "confirms a user" do
      user = insert(:user, is_confirmed: false)
      refute user.is_confirmed
      {:ok, user} = User.confirm(user)
      assert user.is_confirmed
    end

    test "confirms a list of users" do
      unconfirmed_users = [
        insert(:user, is_confirmed: false),
        insert(:user, is_confirmed: false),
        insert(:user, is_confirmed: false)
      ]

      {:ok, users} = User.confirm(unconfirmed_users)

      assert Enum.count(users) == 3

      Enum.each(users, fn user ->
        assert user.is_confirmed
      end)
    end

    test "sends approval emails when `is_approved: false`" do
      admin = insert(:user, is_admin: true)
      user = insert(:user, is_confirmed: false, is_approved: false)
      User.confirm(user)

      ObanHelpers.perform_all()

      user_email = Pleroma.Emails.UserEmail.approval_pending_email(user)
      admin_email = Pleroma.Emails.AdminEmail.new_unapproved_registration(admin, user)

      notify_email = Pleroma.Config.get([:instance, :notify_email])
      instance_name = Pleroma.Config.get([:instance, :name])

      # User approval email
      assert_email_sent(
        from: {instance_name, notify_email},
        to: {user.name, user.email},
        html_body: user_email.html_body
      )

      # Admin email
      assert_email_sent(
        from: {instance_name, notify_email},
        to: {admin.name, admin.email},
        html_body: admin_email.html_body
      )
    end

    test "confirming a confirmed user does not trigger post-register actions" do
      user = insert(:user, is_confirmed: true, is_approved: false)
      User.confirm(user)

      ObanHelpers.perform_all()

      assert_no_email_sent()
    end
  end

  describe "delete" do
    setup do
      {:ok, user} = insert(:user) |> User.set_cache()

      [user: user]
    end

    setup do: clear_config([:instance, :federating])

    test ".delete_user_activities deletes all create activities", %{user: user} do
      {:ok, activity} = CommonAPI.post(user, %{status: "2hu"})

      User.delete_user_activities(user)

      # TODO: Test removal favorites, repeats, delete activities.
      refute Activity.get_by_id(activity.id)
    end

    test "it deactivates a user, all follow relationships and all activities", %{user: user} do
      follower = insert(:user)
      {:ok, follower, user} = User.follow(follower, user)

      locked_user = insert(:user, name: "locked", is_locked: true)
      {:ok, _, _} = User.follow(user, locked_user, :follow_pending)

      object = insert(:note, user: user)
      activity = insert(:note_activity, user: user, note: object)

      object_two = insert(:note, user: follower)
      activity_two = insert(:note_activity, user: follower, note: object_two)

      {:ok, like} = CommonAPI.favorite(user, activity_two.id)
      {:ok, like_two} = CommonAPI.favorite(follower, activity.id)
      {:ok, repeat} = CommonAPI.repeat(activity_two.id, user)

      {:ok, job} = User.delete(user)
      {:ok, _user} = ObanHelpers.perform(job)

      follower = User.get_cached_by_id(follower.id)

      refute User.following?(follower, user)
      assert %{is_active: false} = User.get_by_id(user.id)

      assert [] == User.get_follow_requests(locked_user)

      user_activities =
        user.ap_id
        |> Activity.Queries.by_actor()
        |> Repo.all()
        |> Enum.map(fn act -> act.data["type"] end)

      assert Enum.all?(user_activities, fn act -> act in ~w(Delete Undo) end)

      refute Activity.get_by_id(activity.id)
      refute Activity.get_by_id(like.id)
      refute Activity.get_by_id(like_two.id)
      refute Activity.get_by_id(repeat.id)
    end
  end

  test "delete/1 when confirmation is pending deletes the user" do
    clear_config([:instance, :account_activation_required], true)
    user = insert(:user, is_confirmed: false)

    {:ok, job} = User.delete(user)
    {:ok, _} = ObanHelpers.perform(job)

    refute User.get_cached_by_id(user.id)
    refute User.get_by_id(user.id)
  end

  test "delete/1 when approval is pending deletes the user" do
    user = insert(:user, is_approved: false)

    {:ok, job} = User.delete(user)
    {:ok, _} = ObanHelpers.perform(job)

    refute User.get_cached_by_id(user.id)
    refute User.get_by_id(user.id)
  end

  test "delete/1 purges a user when they wouldn't be fully deleted" do
    user =
      insert(:user, %{
        bio: "eyy lmao",
        name: "qqqqqqq",
        password_hash: "pdfk2$1b3n159001",
        keys: "RSA begin buplic key",
        public_key: "--PRIVATE KEYE--",
        avatar: %{"a" => "b"},
        tags: ["qqqqq"],
        banner: %{"a" => "b"},
        background: %{"a" => "b"},
        note_count: 9,
        follower_count: 9,
        following_count: 9001,
        is_locked: true,
        is_confirmed: true,
        password_reset_pending: true,
        is_approved: true,
        registration_reason: "ahhhhh",
        confirmation_token: "qqqq",
        domain_blocks: ["lain.com"],
        is_active: false,
        ap_enabled: true,
        is_moderator: true,
        is_admin: true,
        mascot: %{"a" => "b"},
        emoji: %{"a" => "b"},
        pleroma_settings_store: %{"q" => "x"},
        fields: [%{"gg" => "qq"}],
        raw_fields: [%{"gg" => "qq"}],
        is_discoverable: true,
        also_known_as: ["https://lol.olo/users/loll"]
      })

    {:ok, job} = User.delete(user)
    {:ok, _} = ObanHelpers.perform(job)
    user = User.get_by_id(user.id)

    assert %User{
             bio: "",
             raw_bio: nil,
             email: nil,
             name: nil,
             password_hash: nil,
             keys: "RSA begin buplic key",
             public_key: "--PRIVATE KEYE--",
             avatar: %{},
             tags: [],
             last_refreshed_at: nil,
             last_digest_emailed_at: nil,
             banner: %{},
             background: %{},
             note_count: 0,
             follower_count: 0,
             following_count: 0,
             is_locked: false,
             is_confirmed: true,
             password_reset_pending: false,
             is_approved: true,
             registration_reason: nil,
             confirmation_token: nil,
             domain_blocks: [],
             is_active: false,
             ap_enabled: false,
             is_moderator: false,
             is_admin: false,
             mascot: nil,
             emoji: %{},
             pleroma_settings_store: %{},
             fields: [],
             raw_fields: [],
             is_discoverable: false,
             also_known_as: []
           } = user
  end

  test "delete/1 purges a remote user" do
    user =
      insert(:user, %{
        name: "qqqqqqq",
        avatar: %{"a" => "b"},
        banner: %{"a" => "b"},
        local: false
      })

    {:ok, job} = User.delete(user)
    {:ok, _} = ObanHelpers.perform(job)
    user = User.get_by_id(user.id)

    assert user.name == nil
    assert user.avatar == %{}
    assert user.banner == %{}
  end

  describe "set_suggestion" do
    test "suggests a user" do
      user = insert(:user, is_suggested: false)
      refute user.is_suggested
      {:ok, user} = User.set_suggestion(user, true)
      assert user.is_suggested
    end

    test "suggests a list of users" do
      unsuggested_users = [
        insert(:user, is_suggested: false),
        insert(:user, is_suggested: false),
        insert(:user, is_suggested: false)
      ]

      {:ok, users} = User.set_suggestion(unsuggested_users, true)

      assert Enum.count(users) == 3

      Enum.each(users, fn user ->
        assert user.is_suggested
      end)
    end

    test "unsuggests a user" do
      user = insert(:user, is_suggested: true)
      assert user.is_suggested
      {:ok, user} = User.set_suggestion(user, false)
      refute user.is_suggested
    end
  end

  test "get_public_key_for_ap_id fetches a user that's not in the db" do
    assert {:ok, _key} = User.get_public_key_for_ap_id("http://mastodon.example.org/users/admin")
  end

  describe "per-user rich-text filtering" do
    test "html_filter_policy returns default policies, when rich-text is enabled" do
      user = insert(:user)

      assert Pleroma.Config.get([:markup, :scrub_policy]) == User.html_filter_policy(user)
    end

    test "html_filter_policy returns TwitterText scrubber when rich-text is disabled" do
      user = insert(:user, no_rich_text: true)

      assert Pleroma.HTML.Scrubber.TwitterText == User.html_filter_policy(user)
    end
  end

  describe "caching" do
    test "invalidate_cache works" do
      user = insert(:user)

      User.set_cache(user)
      User.invalidate_cache(user)

      {:ok, nil} = Cachex.get(:user_cache, "ap_id:#{user.ap_id}")
      {:ok, nil} = Cachex.get(:user_cache, "nickname:#{user.nickname}")
    end

    test "User.delete() plugs any possible zombie objects" do
      user = insert(:user)

      {:ok, job} = User.delete(user)
      {:ok, _} = ObanHelpers.perform(job)

      {:ok, cached_user} = Cachex.get(:user_cache, "ap_id:#{user.ap_id}")

      assert cached_user != user

      {:ok, cached_user} = Cachex.get(:user_cache, "nickname:#{user.ap_id}")

      assert cached_user != user
    end
  end

  describe "account_status/1" do
    setup do: clear_config([:instance, :account_activation_required])

    test "return confirmation_pending for unconfirm user" do
      clear_config([:instance, :account_activation_required], true)
      user = insert(:user, is_confirmed: false)
      assert User.account_status(user) == :confirmation_pending
    end

    test "return active for confirmed user" do
      clear_config([:instance, :account_activation_required], true)
      user = insert(:user, is_confirmed: true)
      assert User.account_status(user) == :active
    end

    test "return active for remote user" do
      user = insert(:user, local: false)
      assert User.account_status(user) == :active
    end

    test "returns :password_reset_pending for user with reset password" do
      user = insert(:user, password_reset_pending: true)
      assert User.account_status(user) == :password_reset_pending
    end

    test "returns :deactivated for deactivated user" do
      user = insert(:user, local: true, is_confirmed: true, is_active: false)
      assert User.account_status(user) == :deactivated
    end

    test "returns :approval_pending for unapproved user" do
      user = insert(:user, local: true, is_approved: false)
      assert User.account_status(user) == :approval_pending

      user = insert(:user, local: true, is_confirmed: false, is_approved: false)
      assert User.account_status(user) == :approval_pending
    end
  end

  describe "superuser?/1" do
    test "returns false for unprivileged users" do
      user = insert(:user, local: true)

      refute User.superuser?(user)
    end

    test "returns false for remote users" do
      user = insert(:user, local: false)
      remote_admin_user = insert(:user, local: false, is_admin: true)

      refute User.superuser?(user)
      refute User.superuser?(remote_admin_user)
    end

    test "returns true for local moderators" do
      user = insert(:user, local: true, is_moderator: true)

      assert User.superuser?(user)
    end

    test "returns true for local admins" do
      user = insert(:user, local: true, is_admin: true)

      assert User.superuser?(user)
    end
  end

  describe "invisible?/1" do
    test "returns true for an invisible user" do
      user = insert(:user, local: true, invisible: true)

      assert User.invisible?(user)
    end

    test "returns false for a non-invisible user" do
      user = insert(:user, local: true)

      refute User.invisible?(user)
    end
  end

  describe "visible_for/2" do
    test "returns true when the account is itself" do
      user = insert(:user, local: true)

      assert User.visible_for(user, user) == :visible
    end

    test "returns false when the account is unconfirmed and confirmation is required" do
      clear_config([:instance, :account_activation_required], true)

      user = insert(:user, local: true, is_confirmed: false)
      other_user = insert(:user, local: true)

      refute User.visible_for(user, other_user) == :visible
    end

    test "returns true when the account is unconfirmed and confirmation is required but the account is remote" do
      clear_config([:instance, :account_activation_required], true)

      user = insert(:user, local: false, is_confirmed: false)
      other_user = insert(:user, local: true)

      assert User.visible_for(user, other_user) == :visible
    end

    test "returns true when the account is unconfirmed and being viewed by a privileged account (confirmation required)" do
      clear_config([:instance, :account_activation_required], true)

      user = insert(:user, local: true, is_confirmed: false)
      other_user = insert(:user, local: true, is_admin: true)

      assert User.visible_for(user, other_user) == :visible
    end
  end

  describe "parse_bio/2" do
    test "preserves hosts in user links text" do
      remote_user = insert(:user, local: false, nickname: "nick@domain.com")
      user = insert(:user)
      bio = "A.k.a. @nick@domain.com"

      expected_text =
        ~s(A.k.a. <span class="h-card"><a class="u-url mention" data-user="#{remote_user.id}" href="#{remote_user.ap_id}" rel="ugc">@<span>nick@domain.com</span></a></span>)

      assert expected_text == User.parse_bio(bio, user)
    end

    test "Adds rel=me on linkbacked urls" do
      user = insert(:user, ap_id: "https://social.example.org/users/lain")

      bio = "http://example.com/rel_me/null"
      expected_text = "<a href=\"#{bio}\">#{bio}</a>"
      assert expected_text == User.parse_bio(bio, user)

      bio = "http://example.com/rel_me/link"
      expected_text = "<a href=\"#{bio}\" rel=\"me\">#{bio}</a>"
      assert expected_text == User.parse_bio(bio, user)

      bio = "http://example.com/rel_me/anchor"
      expected_text = "<a href=\"#{bio}\" rel=\"me\">#{bio}</a>"
      assert expected_text == User.parse_bio(bio, user)
    end
  end

  test "follower count is updated when a follower is blocked" do
    user = insert(:user)
    follower = insert(:user)
    follower2 = insert(:user)
    follower3 = insert(:user)

    {:ok, follower, user} = User.follow(follower, user)
    {:ok, _follower2, _user} = User.follow(follower2, user)
    {:ok, _follower3, _user} = User.follow(follower3, user)

    {:ok, _user_relationship} = User.block(user, follower)
    user = refresh_record(user)

    assert user.follower_count == 2
  end

  describe "list_inactive_users_query/1" do
    defp days_ago(days) do
      NaiveDateTime.add(
        NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
        -days * 60 * 60 * 24,
        :second
      )
    end

    test "Users are inactive by default" do
      total = 10

      users =
        Enum.map(1..total, fn _ ->
          insert(:user, last_digest_emailed_at: days_ago(20), is_active: true)
        end)

      inactive_users_ids =
        Pleroma.User.list_inactive_users_query()
        |> Pleroma.Repo.all()
        |> Enum.map(& &1.id)

      Enum.each(users, fn user ->
        assert user.id in inactive_users_ids
      end)
    end

    test "Only includes users who has no recent activity" do
      total = 10

      users =
        Enum.map(1..total, fn _ ->
          insert(:user, last_digest_emailed_at: days_ago(20), is_active: true)
        end)

      {inactive, active} = Enum.split(users, trunc(total / 2))

      Enum.map(active, fn user ->
        to = Enum.random(users -- [user])

        {:ok, _} =
          CommonAPI.post(user, %{
            status: "hey @#{to.nickname}"
          })
      end)

      inactive_users_ids =
        Pleroma.User.list_inactive_users_query()
        |> Pleroma.Repo.all()
        |> Enum.map(& &1.id)

      Enum.each(active, fn user ->
        refute user.id in inactive_users_ids
      end)

      Enum.each(inactive, fn user ->
        assert user.id in inactive_users_ids
      end)
    end

    test "Only includes users with no read notifications" do
      total = 10

      users =
        Enum.map(1..total, fn _ ->
          insert(:user, last_digest_emailed_at: days_ago(20), is_active: true)
        end)

      [sender | recipients] = users
      {inactive, active} = Enum.split(recipients, trunc(total / 2))

      Enum.each(recipients, fn to ->
        {:ok, _} =
          CommonAPI.post(sender, %{
            status: "hey @#{to.nickname}"
          })

        {:ok, _} =
          CommonAPI.post(sender, %{
            status: "hey again @#{to.nickname}"
          })
      end)

      Enum.each(active, fn user ->
        [n1, _n2] = Pleroma.Notification.for_user(user)
        {:ok, _} = Pleroma.Notification.read_one(user, n1.id)
      end)

      inactive_users_ids =
        Pleroma.User.list_inactive_users_query()
        |> Pleroma.Repo.all()
        |> Enum.map(& &1.id)

      Enum.each(active, fn user ->
        refute user.id in inactive_users_ids
      end)

      Enum.each(inactive, fn user ->
        assert user.id in inactive_users_ids
      end)
    end
  end

  describe "ensure_keys_present" do
    test "it creates keys for a user and stores them in info" do
      user = insert(:user)
      refute is_binary(user.keys)
      {:ok, user} = User.ensure_keys_present(user)
      assert is_binary(user.keys)
    end

    test "it doesn't create keys if there already are some" do
      user = insert(:user, keys: "xxx")
      {:ok, user} = User.ensure_keys_present(user)
      assert user.keys == "xxx"
    end
  end

  describe "get_ap_ids_by_nicknames" do
    test "it returns a list of AP ids for a given set of nicknames" do
      user = insert(:user)
      user_two = insert(:user)

      ap_ids = User.get_ap_ids_by_nicknames([user.nickname, user_two.nickname, "nonexistent"])
      assert length(ap_ids) == 2
      assert user.ap_id in ap_ids
      assert user_two.ap_id in ap_ids
    end

    test "it returns a list of AP ids in the same order" do
      user = insert(:user)
      user_two = insert(:user)
      user_three = insert(:user)

      ap_ids =
        User.get_ap_ids_by_nicknames([user.nickname, user_three.nickname, user_two.nickname])

      assert [user.ap_id, user_three.ap_id, user_two.ap_id] == ap_ids
    end
  end

  describe "sync followers count" do
    setup do
      user1 = insert(:user, local: false, ap_id: "http://localhost:4001/users/masto_closed")
      user2 = insert(:user, local: false, ap_id: "http://localhost:4001/users/fuser2")
      insert(:user, local: true)
      insert(:user, local: false, is_active: false)
      {:ok, user1: user1, user2: user2}
    end

    test "external_users/1 external active users with limit", %{user1: user1, user2: user2} do
      [fdb_user1] = User.external_users(limit: 1)

      assert fdb_user1.ap_id
      assert fdb_user1.ap_id == user1.ap_id
      assert fdb_user1.id == user1.id

      [fdb_user2] = User.external_users(max_id: fdb_user1.id, limit: 1)

      assert fdb_user2.ap_id
      assert fdb_user2.ap_id == user2.ap_id
      assert fdb_user2.id == user2.id

      assert User.external_users(max_id: fdb_user2.id, limit: 1) == []
    end
  end

  describe "is_internal_user?/1" do
    test "non-internal user returns false" do
      user = insert(:user)
      refute User.is_internal_user?(user)
    end

    test "user with no nickname returns true" do
      user = insert(:user, %{nickname: nil})
      assert User.is_internal_user?(user)
    end

    test "user with internal-prefixed nickname returns true" do
      user = insert(:user, %{nickname: "internal.test"})
      assert User.is_internal_user?(user)
    end
  end

  describe "update_and_set_cache/1" do
    test "returns error when user is stale instead Ecto.StaleEntryError" do
      user = insert(:user)

      changeset = Ecto.Changeset.change(user, bio: "test")

      Repo.delete(user)

      assert {:error, %Ecto.Changeset{errors: [id: {"is stale", [stale: true]}], valid?: false}} =
               User.update_and_set_cache(changeset)
    end

    test "performs update cache if user updated" do
      user = insert(:user)
      assert {:ok, nil} = Cachex.get(:user_cache, "ap_id:#{user.ap_id}")

      changeset = Ecto.Changeset.change(user, bio: "test-bio")

      assert {:ok, %User{bio: "test-bio"} = user} = User.update_and_set_cache(changeset)
      assert {:ok, user} = Cachex.get(:user_cache, "ap_id:#{user.ap_id}")
      assert %User{bio: "test-bio"} = User.get_cached_by_ap_id(user.ap_id)
    end
  end

  describe "following/followers synchronization" do
    setup do: clear_config([:instance, :external_user_synchronization])

    test "updates the counters normally on following/getting a follow when disabled" do
      clear_config([:instance, :external_user_synchronization], false)
      user = insert(:user)

      other_user =
        insert(:user,
          local: false,
          follower_address: "http://localhost:4001/users/masto_closed/followers",
          following_address: "http://localhost:4001/users/masto_closed/following",
          ap_enabled: true
        )

      assert other_user.following_count == 0
      assert other_user.follower_count == 0

      {:ok, user, other_user} = Pleroma.User.follow(user, other_user)

      assert user.following_count == 1
      assert other_user.follower_count == 1
    end

    test "syncronizes the counters with the remote instance for the followed when enabled" do
      clear_config([:instance, :external_user_synchronization], false)

      user = insert(:user)

      other_user =
        insert(:user,
          local: false,
          follower_address: "http://localhost:4001/users/masto_closed/followers",
          following_address: "http://localhost:4001/users/masto_closed/following",
          ap_enabled: true
        )

      assert other_user.following_count == 0
      assert other_user.follower_count == 0

      clear_config([:instance, :external_user_synchronization], true)
      {:ok, _user, other_user} = User.follow(user, other_user)

      assert other_user.follower_count == 437
    end

    test "syncronizes the counters with the remote instance for the follower when enabled" do
      clear_config([:instance, :external_user_synchronization], false)

      user = insert(:user)

      other_user =
        insert(:user,
          local: false,
          follower_address: "http://localhost:4001/users/masto_closed/followers",
          following_address: "http://localhost:4001/users/masto_closed/following",
          ap_enabled: true
        )

      assert other_user.following_count == 0
      assert other_user.follower_count == 0

      clear_config([:instance, :external_user_synchronization], true)
      {:ok, other_user, _user} = User.follow(other_user, user)

      assert other_user.following_count == 152
    end
  end

  describe "change_email/2" do
    setup do
      [user: insert(:user)]
    end

    test "blank email returns error if we require an email on registration", %{user: user} do
      orig_account_activation_required =
        Pleroma.Config.get([:instance, :account_activation_required])

      Pleroma.Config.put([:instance, :account_activation_required], true)

      on_exit(fn ->
        Pleroma.Config.put(
          [:instance, :account_activation_required],
          orig_account_activation_required
        )
      end)

      assert {:error, %{errors: [email: {"can't be blank", _}]}} = User.change_email(user, "")
      assert {:error, %{errors: [email: {"can't be blank", _}]}} = User.change_email(user, nil)
    end

    test "blank email should be fine if we do not require an email on registration", %{user: user} do
      orig_account_activation_required =
        Pleroma.Config.get([:instance, :account_activation_required])

      Pleroma.Config.put([:instance, :account_activation_required], false)

      on_exit(fn ->
        Pleroma.Config.put(
          [:instance, :account_activation_required],
          orig_account_activation_required
        )
      end)

      assert {:ok, %User{email: nil}} = User.change_email(user, "")
      assert {:ok, %User{email: nil}} = User.change_email(user, nil)
    end

    test "non unique email returns error", %{user: user} do
      %{email: email} = insert(:user)

      assert {:error, %{errors: [email: {"has already been taken", _}]}} =
               User.change_email(user, email)
    end

    test "invalid email returns error", %{user: user} do
      assert {:error, %{errors: [email: {"has invalid format", _}]}} =
               User.change_email(user, "cofe")
    end

    test "changes email", %{user: user} do
      assert {:ok, %User{email: "cofe@cofe.party"}} = User.change_email(user, "cofe@cofe.party")
    end

    test "adds email", %{user: user} do
      orig_account_activation_required =
        Pleroma.Config.get([:instance, :account_activation_required])

      Pleroma.Config.put([:instance, :account_activation_required], false)

      on_exit(fn ->
        Pleroma.Config.put(
          [:instance, :account_activation_required],
          orig_account_activation_required
        )
      end)

      assert {:ok, _} = User.change_email(user, "")
      Pleroma.Config.put([:instance, :account_activation_required], true)

      assert {:ok, %User{email: "cofe2@cofe.party"}} = User.change_email(user, "cofe2@cofe.party")
    end
  end

  describe "get_cached_by_nickname_or_id" do
    setup do
      local_user = insert(:user)
      remote_user = insert(:user, nickname: "nickname@example.com", local: false)

      [local_user: local_user, remote_user: remote_user]
    end

    setup do: clear_config([:instance, :limit_to_local_content])

    test "allows getting remote users by id no matter what :limit_to_local_content is set to", %{
      remote_user: remote_user
    } do
      clear_config([:instance, :limit_to_local_content], false)
      assert %User{} = User.get_cached_by_nickname_or_id(remote_user.id)

      clear_config([:instance, :limit_to_local_content], true)
      assert %User{} = User.get_cached_by_nickname_or_id(remote_user.id)

      clear_config([:instance, :limit_to_local_content], :unauthenticated)
      assert %User{} = User.get_cached_by_nickname_or_id(remote_user.id)
    end

    test "disallows getting remote users by nickname without authentication when :limit_to_local_content is set to :unauthenticated",
         %{remote_user: remote_user} do
      clear_config([:instance, :limit_to_local_content], :unauthenticated)
      assert nil == User.get_cached_by_nickname_or_id(remote_user.nickname)
    end

    test "allows getting remote users by nickname with authentication when :limit_to_local_content is set to :unauthenticated",
         %{remote_user: remote_user, local_user: local_user} do
      clear_config([:instance, :limit_to_local_content], :unauthenticated)
      assert %User{} = User.get_cached_by_nickname_or_id(remote_user.nickname, for: local_user)
    end

    test "disallows getting remote users by nickname when :limit_to_local_content is set to true",
         %{remote_user: remote_user} do
      clear_config([:instance, :limit_to_local_content], true)
      assert nil == User.get_cached_by_nickname_or_id(remote_user.nickname)
    end

    test "allows getting local users by nickname no matter what :limit_to_local_content is set to",
         %{local_user: local_user} do
      clear_config([:instance, :limit_to_local_content], false)
      assert %User{} = User.get_cached_by_nickname_or_id(local_user.nickname)

      clear_config([:instance, :limit_to_local_content], true)
      assert %User{} = User.get_cached_by_nickname_or_id(local_user.nickname)

      clear_config([:instance, :limit_to_local_content], :unauthenticated)
      assert %User{} = User.get_cached_by_nickname_or_id(local_user.nickname)
    end
  end

  describe "update_email_notifications/2" do
    setup do
      user = insert(:user, email_notifications: %{"digest" => true})

      {:ok, user: user}
    end

    test "Notifications are updated", %{user: user} do
      true = user.email_notifications["digest"]
      assert {:ok, result} = User.update_email_notifications(user, %{"digest" => false})
      assert result.email_notifications["digest"] == false
    end
  end

  describe "local_nickname/1" do
    test "returns nickname without host" do
      assert User.local_nickname("@mentioned") == "mentioned"
      assert User.local_nickname("a_local_nickname") == "a_local_nickname"
      assert User.local_nickname("nickname@host.com") == "nickname"
    end
  end

  describe "full_nickname/1" do
    test "returns fully qualified nickname for local and remote users" do
      local_user =
        insert(:user, nickname: "local_user", ap_id: "https://somehost.com/users/local_user")

      remote_user = insert(:user, nickname: "remote@host.com", local: false)

      assert User.full_nickname(local_user) == "local_user@somehost.com"
      assert User.full_nickname(remote_user) == "remote@host.com"
    end

    test "strips leading @ from mentions" do
      assert User.full_nickname("@mentioned") == "mentioned"
      assert User.full_nickname("@nickname@host.com") == "nickname@host.com"
    end

    test "does not modify nicknames" do
      assert User.full_nickname("nickname") == "nickname"
      assert User.full_nickname("nickname@host.com") == "nickname@host.com"
    end
  end

  test "avatar fallback" do
    user = insert(:user)
    assert User.avatar_url(user) =~ "/images/avi.png"

    clear_config([:assets, :default_user_avatar], "avatar.png")

    user = User.get_cached_by_nickname_or_id(user.nickname)
    assert User.avatar_url(user) =~ "avatar.png"

    assert User.avatar_url(user, no_default: true) == nil
  end

  test "get_host/1" do
    user = insert(:user, ap_id: "https://lain.com/users/lain", nickname: "lain")
    assert User.get_host(user) == "lain.com"
  end

  test "update_last_active_at/1" do
    user = insert(:user)
    assert is_nil(user.last_active_at)

    test_started_at = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    assert {:ok, user} = User.update_last_active_at(user)

    assert user.last_active_at >= test_started_at
    assert user.last_active_at <= NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    last_active_at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-:timer.hours(24), :millisecond)
      |> NaiveDateTime.truncate(:second)

    assert {:ok, user} =
             user
             |> cast(%{last_active_at: last_active_at}, [:last_active_at])
             |> User.update_and_set_cache()

    assert user.last_active_at == last_active_at
    assert {:ok, user} = User.update_last_active_at(user)
    assert user.last_active_at >= test_started_at
    assert user.last_active_at <= NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
  end

  test "active_user_count/1" do
    insert(:user)
    insert(:user, %{local: false})
    insert(:user, %{last_active_at: NaiveDateTime.utc_now()})
    insert(:user, %{last_active_at: Timex.shift(NaiveDateTime.utc_now(), days: -15)})
    insert(:user, %{last_active_at: Timex.shift(NaiveDateTime.utc_now(), weeks: -6)})
    insert(:user, %{last_active_at: Timex.shift(NaiveDateTime.utc_now(), months: -7)})
    insert(:user, %{last_active_at: Timex.shift(NaiveDateTime.utc_now(), years: -2)})

    assert User.active_user_count() == 2
    assert User.active_user_count(180) == 3
    assert User.active_user_count(365) == 4
    assert User.active_user_count(1000) == 5
  end

  describe "pins" do
    setup do
      user = insert(:user)

      [user: user, object_id: object_id_from_created_activity(user)]
    end

    test "unique pins", %{user: user, object_id: object_id} do
      assert {:ok, %{pinned_objects: %{^object_id => pinned_at1} = pins} = updated_user} =
               User.add_pinned_object_id(user, object_id)

      assert Enum.count(pins) == 1

      assert {:ok, %{pinned_objects: %{^object_id => pinned_at2} = pins}} =
               User.add_pinned_object_id(updated_user, object_id)

      assert pinned_at1 == pinned_at2

      assert Enum.count(pins) == 1
    end

    test "respects max_pinned_statuses limit", %{user: user, object_id: object_id} do
      clear_config([:instance, :max_pinned_statuses], 1)
      {:ok, updated} = User.add_pinned_object_id(user, object_id)

      object_id2 = object_id_from_created_activity(user)

      {:error, %{errors: errors}} = User.add_pinned_object_id(updated, object_id2)
      assert Keyword.has_key?(errors, :pinned_objects)
    end

    test "remove_pinned_object_id/2", %{user: user, object_id: object_id} do
      assert {:ok, updated} = User.add_pinned_object_id(user, object_id)

      {:ok, after_remove} = User.remove_pinned_object_id(updated, object_id)
      assert after_remove.pinned_objects == %{}
    end
  end

  defp object_id_from_created_activity(user) do
    %{id: id} = insert(:note_activity, user: user)
    %{object: %{data: %{"id" => object_id}}} = Activity.get_by_id_with_object(id)
    object_id
  end

  describe "account endorsements" do
    test "it pins people" do
      user = insert(:user)
      pinned_user = insert(:user)

      {:ok, _pinned_user, _user} = User.follow(user, pinned_user)

      refute User.endorses?(user, pinned_user)

      {:ok, _user_relationship} = User.endorse(user, pinned_user)

      assert User.endorses?(user, pinned_user)
    end

    test "it unpins users" do
      user = insert(:user)
      pinned_user = insert(:user)

      {:ok, _pinned_user, _user} = User.follow(user, pinned_user)
      {:ok, _user_relationship} = User.endorse(user, pinned_user)
      {:ok, _user_pin} = User.unendorse(user, pinned_user)

      refute User.endorses?(user, pinned_user)
    end

    test "it doesn't pin users you do not follow" do
      user = insert(:user)
      pinned_user = insert(:user)

      assert {:error, _message} = User.endorse(user, pinned_user)

      refute User.endorses?(user, pinned_user)
    end
  end
end
