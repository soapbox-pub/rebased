# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ConversationTest do
  use Pleroma.DataCase
  alias Pleroma.Conversation

  test "it creates a conversation for given ap_id" do
    assert {:ok, %Conversation{}} = Conversation.create_for_ap_id("https://some_ap_id")
  end
end
