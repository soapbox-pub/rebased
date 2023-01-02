# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ChatTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Chat

  import Pleroma.Factory

  describe "creation and getting" do
    test "it only works if the recipient is a valid user (for now)" do
      user = insert(:user)

      assert {:error, _chat} = Chat.bump_or_create(user.id, "http://some/nonexisting/account")
      assert {:error, _chat} = Chat.get_or_create(user.id, "http://some/nonexisting/account")
    end

    test "it creates a chat for a user and recipient" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, chat} = Chat.bump_or_create(user.id, other_user.ap_id)

      assert chat.id
    end

    test "deleting the user deletes the chat" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, chat} = Chat.bump_or_create(user.id, other_user.ap_id)

      Repo.delete(user)

      refute Chat.get_by_id(chat.id)
    end

    test "deleting the recipient deletes the chat" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, chat} = Chat.bump_or_create(user.id, other_user.ap_id)

      Repo.delete(other_user)

      refute Chat.get_by_id(chat.id)
    end

    test "it returns and bumps a chat for a user and recipient if it already exists" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, chat} = Chat.bump_or_create(user.id, other_user.ap_id)
      {:ok, chat_two} = Chat.bump_or_create(user.id, other_user.ap_id)

      assert chat.id == chat_two.id
    end

    test "it returns a chat for a user and recipient if it already exists" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, chat} = Chat.get_or_create(user.id, other_user.ap_id)
      {:ok, chat_two} = Chat.get_or_create(user.id, other_user.ap_id)

      assert chat.id == chat_two.id
    end

    test "a returning chat will have an updated `update_at` field" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, chat} = Chat.bump_or_create(user.id, other_user.ap_id)
      {:ok, chat} = time_travel(chat, -2)

      {:ok, chat_two} = Chat.bump_or_create(user.id, other_user.ap_id)

      assert chat.id == chat_two.id
      assert chat.updated_at != chat_two.updated_at
    end
  end
end
