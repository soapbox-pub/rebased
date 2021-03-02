# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.MigrationHelper.NotificationBackfillTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Activity
  alias Pleroma.MigrationHelper.NotificationBackfill
  alias Pleroma.Notification
  alias Pleroma.Repo
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "fill_in_notification_types" do
    test "it fills in missing notification types" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, post} = CommonAPI.post(user, %{status: "yeah, @#{other_user.nickname}"})
      {:ok, chat} = CommonAPI.post_chat_message(user, other_user, "yo")
      {:ok, react} = CommonAPI.react_with_emoji(post.id, other_user, "☕")
      {:ok, like} = CommonAPI.favorite(other_user, post.id)
      {:ok, react_2} = CommonAPI.react_with_emoji(post.id, other_user, "☕")

      data =
        react_2.data
        |> Map.put("type", "EmojiReaction")

      {:ok, react_2} =
        react_2
        |> Activity.change(%{data: data})
        |> Repo.update()

      assert {5, nil} = Repo.update_all(Notification, set: [type: nil])

      NotificationBackfill.fill_in_notification_types()

      assert %{type: "mention"} =
               Repo.get_by(Notification, user_id: other_user.id, activity_id: post.id)

      assert %{type: "favourite"} =
               Repo.get_by(Notification, user_id: user.id, activity_id: like.id)

      assert %{type: "pleroma:emoji_reaction"} =
               Repo.get_by(Notification, user_id: user.id, activity_id: react.id)

      assert %{type: "pleroma:emoji_reaction"} =
               Repo.get_by(Notification, user_id: user.id, activity_id: react_2.id)

      assert %{type: "pleroma:chat_mention"} =
               Repo.get_by(Notification, user_id: other_user.id, activity_id: chat.id)
    end
  end
end
