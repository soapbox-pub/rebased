# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.SideEffectsTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Chat
  alias Pleroma.Chat.MessageReference
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.SideEffects
  alias Pleroma.Web.CommonAPI

  import Mock
  import Pleroma.Factory

  describe "handle_after_transaction" do
    test "it streams out notifications and streams" do
      author = insert(:user, local: true)
      recipient = insert(:user, local: true)

      {:ok, chat_message_data, _meta} = Builder.chat_message(author, recipient.ap_id, "hey")

      {:ok, create_activity_data, _meta} =
        Builder.create(author, chat_message_data["id"], [recipient.ap_id])

      {:ok, create_activity, _meta} = ActivityPub.persist(create_activity_data, local: false)

      {:ok, _create_activity, meta} =
        SideEffects.handle(create_activity, local: false, object_data: chat_message_data)

      assert [notification] = meta[:notifications]

      with_mocks([
        {
          Pleroma.Web.Streamer,
          [],
          [
            stream: fn _, _ -> nil end
          ]
        },
        {
          Pleroma.Web.Push,
          [],
          [
            send: fn _ -> nil end
          ]
        }
      ]) do
        SideEffects.handle_after_transaction(meta)

        assert called(Pleroma.Web.Streamer.stream(["user", "user:notification"], notification))
        assert called(Pleroma.Web.Streamer.stream(["user", "user:pleroma_chat"], :_))
        assert called(Pleroma.Web.Push.send(notification))
      end
    end
  end

  describe "blocking users" do
    setup do
      user = insert(:user)
      blocked = insert(:user)
      User.follow(blocked, user)
      User.follow(user, blocked)

      {:ok, block_data, []} = Builder.block(user, blocked)
      {:ok, block, _meta} = ActivityPub.persist(block_data, local: true)

      %{user: user, blocked: blocked, block: block}
    end

    test "it unfollows and blocks", %{user: user, blocked: blocked, block: block} do
      assert User.following?(user, blocked)
      assert User.following?(blocked, user)

      {:ok, _, _} = SideEffects.handle(block)

      refute User.following?(user, blocked)
      refute User.following?(blocked, user)
      assert User.blocks?(user, blocked)
    end

    test "it updates following relationship", %{user: user, blocked: blocked, block: block} do
      {:ok, _, _} = SideEffects.handle(block)

      refute Pleroma.FollowingRelationship.get(user, blocked)
      assert User.get_follow_state(user, blocked) == nil
      assert User.get_follow_state(blocked, user) == nil
      assert User.get_follow_state(user, blocked, nil) == nil
      assert User.get_follow_state(blocked, user, nil) == nil
    end

    test "it blocks but does not unfollow if the relevant setting is set", %{
      user: user,
      blocked: blocked,
      block: block
    } do
      clear_config([:activitypub, :unfollow_blocked], false)
      assert User.following?(user, blocked)
      assert User.following?(blocked, user)

      {:ok, _, _} = SideEffects.handle(block)

      refute User.following?(user, blocked)
      assert User.following?(blocked, user)
      assert User.blocks?(user, blocked)
    end
  end

  describe "update users" do
    setup do
      user = insert(:user, local: false)
      {:ok, update_data, []} = Builder.update(user, %{"id" => user.ap_id, "name" => "new name!"})
      {:ok, update, _meta} = ActivityPub.persist(update_data, local: true)

      %{user: user, update_data: update_data, update: update}
    end

    test "it updates the user", %{user: user, update: update} do
      {:ok, _, _} = SideEffects.handle(update)
      user = User.get_by_id(user.id)
      assert user.name == "new name!"
    end

    test "it uses a given changeset to update", %{user: user, update: update} do
      changeset = Ecto.Changeset.change(user, %{default_scope: "direct"})

      assert user.default_scope == "public"
      {:ok, _, _} = SideEffects.handle(update, user_update_changeset: changeset)
      user = User.get_by_id(user.id)
      assert user.default_scope == "direct"
    end
  end

  describe "EmojiReact objects" do
    setup do
      poster = insert(:user)
      user = insert(:user)

      {:ok, post} = CommonAPI.post(poster, %{status: "hey"})

      {:ok, emoji_react_data, []} = Builder.emoji_react(user, post.object, "👌")
      {:ok, emoji_react, _meta} = ActivityPub.persist(emoji_react_data, local: true)

      %{emoji_react: emoji_react, user: user, poster: poster}
    end

    test "adds the reaction to the object", %{emoji_react: emoji_react, user: user} do
      {:ok, emoji_react, _} = SideEffects.handle(emoji_react)
      object = Object.get_by_ap_id(emoji_react.data["object"])

      assert object.data["reaction_count"] == 1
      assert ["👌", [user.ap_id]] in object.data["reactions"]
    end

    test "creates a notification", %{emoji_react: emoji_react, poster: poster} do
      {:ok, emoji_react, _} = SideEffects.handle(emoji_react)
      assert Repo.get_by(Notification, user_id: poster.id, activity_id: emoji_react.id)
    end
  end

  describe "Question objects" do
    setup do
      user = insert(:user)
      question = build(:question, user: user)
      question_activity = build(:question_activity, question: question)
      activity_data = Map.put(question_activity.data, "object", question.data["id"])
      meta = [object_data: question.data, local: false]

      {:ok, activity, meta} = ActivityPub.persist(activity_data, meta)

      %{activity: activity, meta: meta}
    end

    test "enqueues the poll end", %{activity: activity, meta: meta} do
      {:ok, activity, meta} = SideEffects.handle(activity, meta)

      assert_enqueued(
        worker: Pleroma.Workers.PollWorker,
        args: %{op: "poll_end", activity_id: activity.id},
        scheduled_at: NaiveDateTime.from_iso8601!(meta[:object_data]["closed"])
      )
    end
  end

  describe "delete users with confirmation pending" do
    setup do
      user = insert(:user, is_confirmed: false)
      {:ok, delete_user_data, _meta} = Builder.delete(user, user.ap_id)
      {:ok, delete_user, _meta} = ActivityPub.persist(delete_user_data, local: true)
      {:ok, delete: delete_user, user: user}
    end

    test "when activation is required", %{delete: delete, user: user} do
      clear_config([:instance, :account_activation_required], true)
      {:ok, _, _} = SideEffects.handle(delete)
      ObanHelpers.perform_all()

      refute User.get_cached_by_id(user.id)
    end
  end

  describe "Undo objects" do
    setup do
      poster = insert(:user)
      user = insert(:user)
      {:ok, post} = CommonAPI.post(poster, %{status: "hey"})
      {:ok, like} = CommonAPI.favorite(user, post.id)
      {:ok, reaction} = CommonAPI.react_with_emoji(post.id, user, "👍")
      {:ok, announce} = CommonAPI.repeat(post.id, user)
      {:ok, block} = CommonAPI.block(user, poster)

      {:ok, undo_data, _meta} = Builder.undo(user, like)
      {:ok, like_undo, _meta} = ActivityPub.persist(undo_data, local: true)

      {:ok, undo_data, _meta} = Builder.undo(user, reaction)
      {:ok, reaction_undo, _meta} = ActivityPub.persist(undo_data, local: true)

      {:ok, undo_data, _meta} = Builder.undo(user, announce)
      {:ok, announce_undo, _meta} = ActivityPub.persist(undo_data, local: true)

      {:ok, undo_data, _meta} = Builder.undo(user, block)
      {:ok, block_undo, _meta} = ActivityPub.persist(undo_data, local: true)

      %{
        like_undo: like_undo,
        post: post,
        like: like,
        reaction_undo: reaction_undo,
        reaction: reaction,
        announce_undo: announce_undo,
        announce: announce,
        block_undo: block_undo,
        block: block,
        poster: poster,
        user: user
      }
    end

    test "deletes the original block", %{
      block_undo: block_undo,
      block: block
    } do
      {:ok, _block_undo, _meta} = SideEffects.handle(block_undo)

      refute Activity.get_by_id(block.id)
    end

    test "unblocks the blocked user", %{block_undo: block_undo, block: block} do
      blocker = User.get_by_ap_id(block.data["actor"])
      blocked = User.get_by_ap_id(block.data["object"])

      {:ok, _block_undo, _} = SideEffects.handle(block_undo)
      refute User.blocks?(blocker, blocked)
    end

    test "an announce undo removes the announce from the object", %{
      announce_undo: announce_undo,
      post: post
    } do
      {:ok, _announce_undo, _} = SideEffects.handle(announce_undo)

      object = Object.get_by_ap_id(post.data["object"])

      assert object.data["announcement_count"] == 0
      assert object.data["announcements"] == []
    end

    test "deletes the original announce", %{announce_undo: announce_undo, announce: announce} do
      {:ok, _announce_undo, _} = SideEffects.handle(announce_undo)
      refute Activity.get_by_id(announce.id)
    end

    test "a reaction undo removes the reaction from the object", %{
      reaction_undo: reaction_undo,
      post: post
    } do
      {:ok, _reaction_undo, _} = SideEffects.handle(reaction_undo)

      object = Object.get_by_ap_id(post.data["object"])

      assert object.data["reaction_count"] == 0
      assert object.data["reactions"] == []
    end

    test "deletes the original reaction", %{reaction_undo: reaction_undo, reaction: reaction} do
      {:ok, _reaction_undo, _} = SideEffects.handle(reaction_undo)
      refute Activity.get_by_id(reaction.id)
    end

    test "a like undo removes the like from the object", %{like_undo: like_undo, post: post} do
      {:ok, _like_undo, _} = SideEffects.handle(like_undo)

      object = Object.get_by_ap_id(post.data["object"])

      assert object.data["like_count"] == 0
      assert object.data["likes"] == []
    end

    test "deletes the original like", %{like_undo: like_undo, like: like} do
      {:ok, _like_undo, _} = SideEffects.handle(like_undo)
      refute Activity.get_by_id(like.id)
    end
  end

  describe "like objects" do
    setup do
      poster = insert(:user)
      user = insert(:user)
      {:ok, post} = CommonAPI.post(poster, %{status: "hey"})

      {:ok, like_data, _meta} = Builder.like(user, post.object)
      {:ok, like, _meta} = ActivityPub.persist(like_data, local: true)

      %{like: like, user: user, poster: poster}
    end

    test "add the like to the original object", %{like: like, user: user} do
      {:ok, like, _} = SideEffects.handle(like)
      object = Object.get_by_ap_id(like.data["object"])
      assert object.data["like_count"] == 1
      assert user.ap_id in object.data["likes"]
    end

    test "creates a notification", %{like: like, poster: poster} do
      {:ok, like, _} = SideEffects.handle(like)
      assert Repo.get_by(Notification, user_id: poster.id, activity_id: like.id)
    end
  end

  describe "creation of ChatMessages" do
    test "notifies the recipient" do
      author = insert(:user, local: false)
      recipient = insert(:user, local: true)

      {:ok, chat_message_data, _meta} = Builder.chat_message(author, recipient.ap_id, "hey")

      {:ok, create_activity_data, _meta} =
        Builder.create(author, chat_message_data["id"], [recipient.ap_id])

      {:ok, create_activity, _meta} = ActivityPub.persist(create_activity_data, local: false)

      {:ok, _create_activity, _meta} =
        SideEffects.handle(create_activity, local: false, object_data: chat_message_data)

      assert Repo.get_by(Notification, user_id: recipient.id, activity_id: create_activity.id)
    end

    test "it streams the created ChatMessage" do
      author = insert(:user, local: true)
      recipient = insert(:user, local: true)

      {:ok, chat_message_data, _meta} = Builder.chat_message(author, recipient.ap_id, "hey")

      {:ok, create_activity_data, _meta} =
        Builder.create(author, chat_message_data["id"], [recipient.ap_id])

      {:ok, create_activity, _meta} = ActivityPub.persist(create_activity_data, local: false)

      {:ok, _create_activity, meta} =
        SideEffects.handle(create_activity, local: false, object_data: chat_message_data)

      assert [_, _] = meta[:streamables]
    end

    test "it creates a Chat and MessageReferences for the local users and bumps the unread count, except for the author" do
      author = insert(:user, local: true)
      recipient = insert(:user, local: true)

      {:ok, chat_message_data, _meta} = Builder.chat_message(author, recipient.ap_id, "hey")

      {:ok, create_activity_data, _meta} =
        Builder.create(author, chat_message_data["id"], [recipient.ap_id])

      {:ok, create_activity, _meta} = ActivityPub.persist(create_activity_data, local: false)

      with_mocks([
        {
          Pleroma.Web.Streamer,
          [],
          [
            stream: fn _, _ -> nil end
          ]
        },
        {
          Pleroma.Web.Push,
          [],
          [
            send: fn _ -> nil end
          ]
        }
      ]) do
        {:ok, _create_activity, meta} =
          SideEffects.handle(create_activity, local: false, object_data: chat_message_data)

        # The notification gets created
        assert [notification] = meta[:notifications]
        assert notification.activity_id == create_activity.id

        # But it is not sent out
        refute called(Pleroma.Web.Streamer.stream(["user", "user:notification"], notification))
        refute called(Pleroma.Web.Push.send(notification))

        # Same for the user chat stream
        assert [{topics, _}, _] = meta[:streamables]
        assert topics == ["user", "user:pleroma_chat"]
        refute called(Pleroma.Web.Streamer.stream(["user", "user:pleroma_chat"], :_))

        chat = Chat.get(author.id, recipient.ap_id)

        [cm_ref] = MessageReference.for_chat_query(chat) |> Repo.all()

        assert cm_ref.object.data["content"] == "hey"
        assert cm_ref.unread == false

        chat = Chat.get(recipient.id, author.ap_id)

        [cm_ref] = MessageReference.for_chat_query(chat) |> Repo.all()

        assert cm_ref.object.data["content"] == "hey"
        assert cm_ref.unread == true
      end
    end

    test "it creates a Chat for the local users and bumps the unread count" do
      author = insert(:user, local: false)
      recipient = insert(:user, local: true)

      {:ok, chat_message_data, _meta} = Builder.chat_message(author, recipient.ap_id, "hey")

      {:ok, create_activity_data, _meta} =
        Builder.create(author, chat_message_data["id"], [recipient.ap_id])

      {:ok, create_activity, _meta} = ActivityPub.persist(create_activity_data, local: false)

      {:ok, _create_activity, _meta} =
        SideEffects.handle(create_activity, local: false, object_data: chat_message_data)

      # An object is created
      assert Object.get_by_ap_id(chat_message_data["id"])

      # The remote user won't get a chat
      chat = Chat.get(author.id, recipient.ap_id)
      refute chat

      # The local user will get a chat
      chat = Chat.get(recipient.id, author.ap_id)
      assert chat

      author = insert(:user, local: true)
      recipient = insert(:user, local: true)

      {:ok, chat_message_data, _meta} = Builder.chat_message(author, recipient.ap_id, "hey")

      {:ok, create_activity_data, _meta} =
        Builder.create(author, chat_message_data["id"], [recipient.ap_id])

      {:ok, create_activity, _meta} = ActivityPub.persist(create_activity_data, local: false)

      {:ok, _create_activity, _meta} =
        SideEffects.handle(create_activity, local: false, object_data: chat_message_data)

      # Both users are local and get the chat
      chat = Chat.get(author.id, recipient.ap_id)
      assert chat

      chat = Chat.get(recipient.id, author.ap_id)
      assert chat
    end
  end

  describe "announce objects" do
    setup do
      poster = insert(:user)
      user = insert(:user)
      {:ok, post} = CommonAPI.post(poster, %{status: "hey"})
      {:ok, private_post} = CommonAPI.post(poster, %{status: "hey", visibility: "private"})

      {:ok, announce_data, _meta} = Builder.announce(user, post.object, public: true)

      {:ok, private_announce_data, _meta} =
        Builder.announce(user, private_post.object, public: false)

      {:ok, relay_announce_data, _meta} =
        Builder.announce(Pleroma.Web.ActivityPub.Relay.get_actor(), post.object, public: true)

      {:ok, announce, _meta} = ActivityPub.persist(announce_data, local: true)
      {:ok, private_announce, _meta} = ActivityPub.persist(private_announce_data, local: true)
      {:ok, relay_announce, _meta} = ActivityPub.persist(relay_announce_data, local: true)

      %{
        announce: announce,
        user: user,
        poster: poster,
        private_announce: private_announce,
        relay_announce: relay_announce
      }
    end

    test "adds the announce to the original object", %{announce: announce, user: user} do
      {:ok, announce, _} = SideEffects.handle(announce)
      object = Object.get_by_ap_id(announce.data["object"])
      assert object.data["announcement_count"] == 1
      assert user.ap_id in object.data["announcements"]
    end

    test "does not add the announce to the original object if the actor is a service actor", %{
      relay_announce: announce
    } do
      {:ok, announce, _} = SideEffects.handle(announce)
      object = Object.get_by_ap_id(announce.data["object"])
      assert object.data["announcement_count"] == nil
    end

    test "creates a notification", %{announce: announce, poster: poster} do
      {:ok, announce, _} = SideEffects.handle(announce)
      assert Repo.get_by(Notification, user_id: poster.id, activity_id: announce.id)
    end

    test "it streams out the announce", %{announce: announce} do
      with_mocks([
        {
          Pleroma.Web.Streamer,
          [],
          [
            stream: fn _, _ -> nil end
          ]
        },
        {
          Pleroma.Web.Push,
          [],
          [
            send: fn _ -> nil end
          ]
        }
      ]) do
        {:ok, announce, _} = SideEffects.handle(announce)

        assert called(
                 Pleroma.Web.Streamer.stream(["user", "list", "public", "public:local"], announce)
               )

        assert called(Pleroma.Web.Push.send(:_))
      end
    end
  end

  describe "removing a follower" do
    setup do
      user = insert(:user)
      followed = insert(:user)

      {:ok, _, _, follow_activity} = CommonAPI.follow(user, followed)

      {:ok, reject_data, []} = Builder.reject(followed, follow_activity)
      {:ok, reject, _meta} = ActivityPub.persist(reject_data, local: true)

      %{user: user, followed: followed, reject: reject}
    end

    test "", %{user: user, followed: followed, reject: reject} do
      assert User.following?(user, followed)
      assert Pleroma.FollowingRelationship.get(user, followed)

      {:ok, _, _} = SideEffects.handle(reject)

      refute User.following?(user, followed)
      refute Pleroma.FollowingRelationship.get(user, followed)
      assert User.get_follow_state(user, followed) == nil
      assert User.get_follow_state(user, followed, nil) == nil
    end
  end

  describe "removing a follower from remote" do
    setup do
      user = insert(:user)
      followed = insert(:user, local: false)

      # Mock a local-to-remote follow
      {:ok, follow_data, []} = Builder.follow(user, followed)

      follow_data =
        follow_data
        |> Map.put("state", "accept")

      {:ok, follow, _meta} = ActivityPub.persist(follow_data, local: true)
      {:ok, _, _} = SideEffects.handle(follow)

      # Mock a remote-to-local accept
      {:ok, accept_data, _} = Builder.accept(followed, follow)
      {:ok, accept, _} = ActivityPub.persist(accept_data, local: false)
      {:ok, _, _} = SideEffects.handle(accept)

      # Mock a remote-to-local reject
      {:ok, reject_data, []} = Builder.reject(followed, follow)
      {:ok, reject, _meta} = ActivityPub.persist(reject_data, local: false)

      %{user: user, followed: followed, reject: reject}
    end

    test "", %{user: user, followed: followed, reject: reject} do
      assert User.following?(user, followed)
      assert Pleroma.FollowingRelationship.get(user, followed)

      {:ok, _, _} = SideEffects.handle(reject)

      refute User.following?(user, followed)
      refute Pleroma.FollowingRelationship.get(user, followed)

      assert Pleroma.Web.ActivityPub.Utils.fetch_latest_follow(user, followed).data["state"] ==
               "reject"

      assert User.get_follow_state(user, followed) == nil
      assert User.get_follow_state(user, followed, nil) == nil
    end
  end
end
