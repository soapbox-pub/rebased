# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
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

    test "it returns a chat for a user and recipient if it already exists" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, chat} = Chat.bump_or_create(user.id, other_user.ap_id)
      {:ok, chat_two} = Chat.bump_or_create(user.id, other_user.ap_id)

      assert chat.id == chat_two.id
    end

    test "a returning chat will have an updated `update_at` field and an incremented unread count" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, chat} = Chat.bump_or_create(user.id, other_user.ap_id)
      assert chat.unread == 1
      :timer.sleep(1500)
      {:ok, chat_two} = Chat.bump_or_create(user.id, other_user.ap_id)
      assert chat_two.unread == 2

      assert chat.id == chat_two.id
      assert chat.updated_at != chat_two.updated_at
    end
  end
end
