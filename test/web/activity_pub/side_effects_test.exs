# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.SideEffectsTest do
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.SideEffects
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "Undo objects" do
    setup do
      poster = insert(:user)
      user = insert(:user)
      {:ok, post} = CommonAPI.post(poster, %{"status" => "hey"})
      {:ok, like} = CommonAPI.favorite(user, post.id)
      {:ok, reaction, _} = CommonAPI.react_with_emoji(post.id, user, "👍")
      {:ok, announce, _} = CommonAPI.repeat(post.id, user)
      {:ok, block} = ActivityPub.block(user, poster)
      User.block(user, poster)

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

    test "deletes the original block", %{block_undo: block_undo, block: block} do
      {:ok, _block_undo, _} = SideEffects.handle(block_undo)
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
      {:ok, post} = CommonAPI.post(poster, %{"status" => "hey"})

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
end
