# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.SideEffectsTest do
  use Pleroma.DataCase

  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.SideEffects
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "EmojiReact objects" do
    setup do
      poster = insert(:user)
      user = insert(:user)

      {:ok, post} = CommonAPI.post(poster, %{"status" => "hey"})

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
