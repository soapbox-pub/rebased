# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Conversation.ParticipationTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.Conversation.Participation

  test "it creates a participation for a conversation and a user" do
    user = insert(:user)
    conversation = insert(:conversation)

    {:ok, %Participation{} = participation} =
      Participation.create_for_user_and_conversation(user, conversation)

    assert participation.user_id == user.id
    assert participation.conversation_id == conversation.id

    :timer.sleep(1000)
    # Creating again returns the same participation
    {:ok, %Participation{} = participation_two} =
      Participation.create_for_user_and_conversation(user, conversation)

    assert participation.id == participation_two.id
    refute participation.updated_at == participation_two.updated_at
  end

  test "recreating an existing participations sets it to unread" do
    participation = insert(:participation, %{read: true})

    {:ok, participation} =
      Participation.create_for_user_and_conversation(
        participation.user,
        participation.conversation
      )

    refute participation.read
  end

  test "it marks a participation as read" do
    participation = insert(:participation, %{read: false})
    {:ok, participation} = Participation.mark_as_read(participation)

    assert participation.read
  end

  test "it marks a participation as unread" do
    participation = insert(:participation, %{read: true})
    {:ok, participation} = Participation.mark_as_unread(participation)

    refute participation.read
  end
end
