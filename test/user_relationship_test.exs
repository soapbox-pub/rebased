# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.UserRelationshipTest do
  alias Pleroma.UserRelationship

  use Pleroma.DataCase

  import Pleroma.Factory

  describe "*_exists?/2" do
    setup do
      {:ok, users: insert_list(2, :user)}
    end

    test "returns false if record doesn't exist", %{users: [user1, user2]} do
      refute UserRelationship.block_exists?(user1, user2)
      refute UserRelationship.mute_exists?(user1, user2)
      refute UserRelationship.notification_mute_exists?(user1, user2)
      refute UserRelationship.reblog_mute_exists?(user1, user2)
      refute UserRelationship.inverse_subscription_exists?(user1, user2)
    end

    test "returns true if record exists", %{users: [user1, user2]} do
      for relationship_type <- [
            :block,
            :mute,
            :notification_mute,
            :reblog_mute,
            :inverse_subscription
          ] do
        insert(:user_relationship,
          source: user1,
          target: user2,
          relationship_type: relationship_type
        )
      end

      assert UserRelationship.block_exists?(user1, user2)
      assert UserRelationship.mute_exists?(user1, user2)
      assert UserRelationship.notification_mute_exists?(user1, user2)
      assert UserRelationship.reblog_mute_exists?(user1, user2)
      assert UserRelationship.inverse_subscription_exists?(user1, user2)
    end
  end

  describe "create_*/2" do
    setup do
      {:ok, users: insert_list(2, :user)}
    end

    test "creates user relationship record if it doesn't exist", %{users: [user1, user2]} do
      for relationship_type <- [
            :block,
            :mute,
            :notification_mute,
            :reblog_mute,
            :inverse_subscription
          ] do
        insert(:user_relationship,
          source: user1,
          target: user2,
          relationship_type: relationship_type
        )
      end

      UserRelationship.create_block(user1, user2)
      UserRelationship.create_mute(user1, user2)
      UserRelationship.create_notification_mute(user1, user2)
      UserRelationship.create_reblog_mute(user1, user2)
      UserRelationship.create_inverse_subscription(user1, user2)

      assert UserRelationship.block_exists?(user1, user2)
      assert UserRelationship.mute_exists?(user1, user2)
      assert UserRelationship.notification_mute_exists?(user1, user2)
      assert UserRelationship.reblog_mute_exists?(user1, user2)
      assert UserRelationship.inverse_subscription_exists?(user1, user2)
    end

    test "if record already exists, returns it", %{users: [user1, user2]} do
      user_block = UserRelationship.create_block(user1, user2)
      assert user_block == UserRelationship.create_block(user1, user2)
    end
  end

  describe "delete_*/2" do
    setup do
      {:ok, users: insert_list(2, :user)}
    end

    test "deletes user relationship record if it exists", %{users: [user1, user2]} do
      for relationship_type <- [
            :block,
            :mute,
            :notification_mute,
            :reblog_mute,
            :inverse_subscription
          ] do
        insert(:user_relationship,
          source: user1,
          target: user2,
          relationship_type: relationship_type
        )
      end

      assert {:ok, %UserRelationship{}} = UserRelationship.delete_block(user1, user2)
      assert {:ok, %UserRelationship{}} = UserRelationship.delete_mute(user1, user2)
      assert {:ok, %UserRelationship{}} = UserRelationship.delete_notification_mute(user1, user2)
      assert {:ok, %UserRelationship{}} = UserRelationship.delete_reblog_mute(user1, user2)

      assert {:ok, %UserRelationship{}} =
               UserRelationship.delete_inverse_subscription(user1, user2)

      refute UserRelationship.block_exists?(user1, user2)
      refute UserRelationship.mute_exists?(user1, user2)
      refute UserRelationship.notification_mute_exists?(user1, user2)
      refute UserRelationship.reblog_mute_exists?(user1, user2)
      refute UserRelationship.inverse_subscription_exists?(user1, user2)
    end

    test "if record does not exist, returns {:ok, nil}", %{users: [user1, user2]} do
      assert {:ok, nil} = UserRelationship.delete_block(user1, user2)
      assert {:ok, nil} = UserRelationship.delete_mute(user1, user2)
      assert {:ok, nil} = UserRelationship.delete_notification_mute(user1, user2)
      assert {:ok, nil} = UserRelationship.delete_reblog_mute(user1, user2)
      assert {:ok, nil} = UserRelationship.delete_inverse_subscription(user1, user2)
    end
  end
end
