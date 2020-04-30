# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.SideEffectsTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.SideEffects
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "delete objects" do
    setup do
      user = insert(:user)
      {:ok, post} = CommonAPI.post(user, %{"status" => "hey"})
      object = Object.normalize(post)
      {:ok, delete_data, _meta} = Builder.delete(user, object.data["id"])
      {:ok, delete_user_data, _meta} = Builder.delete(user, user.ap_id)
      {:ok, delete, _meta} = ActivityPub.persist(delete_data, local: true)
      {:ok, delete_user, _meta} = ActivityPub.persist(delete_user_data, local: true)
      %{user: user, delete: delete, post: post, object: object, delete_user: delete_user}
    end

    test "it handles object deletions", %{delete: delete, post: post, object: object} do
      # In object deletions, the object is replaced by a tombstone and the
      # create activity is deleted

      {:ok, _delete, _} = SideEffects.handle(delete)

      object = Object.get_by_id(object.id)
      assert object.data["type"] == "Tombstone"
      refute Activity.get_by_id(post.id)
    end

    test "it handles user deletions", %{delete_user: delete, user: user} do
      {:ok, _delete, _} = SideEffects.handle(delete)
      ObanHelpers.perform_all()

      refute User.get_cached_by_ap_id(user.ap_id)
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
