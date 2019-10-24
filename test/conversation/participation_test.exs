# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Conversation.ParticipationTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.Conversation.Participation
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  test "getting a participation will also preload things" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, _activity} =
      CommonAPI.post(user, %{"status" => "Hey @#{other_user.nickname}.", "visibility" => "direct"})

    [participation] = Participation.for_user(user)

    participation = Participation.get(participation.id, preload: [:conversation])

    assert %Pleroma.Conversation{} = participation.conversation
  end

  test "for a new conversation or a reply, it doesn't mark the author's participation as unread" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, _} =
      CommonAPI.post(user, %{"status" => "Hey @#{other_user.nickname}.", "visibility" => "direct"})

    user = User.get_cached_by_id(user.id)
    other_user = User.get_cached_by_id(other_user.id)

    [%{read: true}] = Participation.for_user(user)
    [%{read: false} = participation] = Participation.for_user(other_user)

    assert User.get_cached_by_id(user.id).unread_conversation_count == 0
    assert User.get_cached_by_id(other_user.id).unread_conversation_count == 1

    {:ok, _} =
      CommonAPI.post(other_user, %{
        "status" => "Hey @#{user.nickname}.",
        "visibility" => "direct",
        "in_reply_to_conversation_id" => participation.id
      })

    user = User.get_cached_by_id(user.id)
    other_user = User.get_cached_by_id(other_user.id)

    [%{read: false}] = Participation.for_user(user)
    [%{read: true}] = Participation.for_user(other_user)

    assert User.get_cached_by_id(user.id).unread_conversation_count == 1
    assert User.get_cached_by_id(other_user.id).unread_conversation_count == 0
  end

  test "for a new conversation, it sets the recipents of the participation" do
    user = insert(:user)
    other_user = insert(:user)
    third_user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{"status" => "Hey @#{other_user.nickname}.", "visibility" => "direct"})

    user = User.get_cached_by_id(user.id)
    other_user = User.get_cached_by_id(other_user.id)
    [participation] = Participation.for_user(user)
    participation = Pleroma.Repo.preload(participation, :recipients)

    assert length(participation.recipients) == 2
    assert user in participation.recipients
    assert other_user in participation.recipients

    # Mentioning another user in the same conversation will not add a new recipients.

    {:ok, _activity} =
      CommonAPI.post(user, %{
        "in_reply_to_status_id" => activity.id,
        "status" => "Hey @#{third_user.nickname}.",
        "visibility" => "direct"
      })

    [participation] = Participation.for_user(user)
    participation = Pleroma.Repo.preload(participation, :recipients)

    assert length(participation.recipients) == 2
  end

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

  test "it marks all the user's participations as read" do
    user = insert(:user)
    other_user = insert(:user)
    participation1 = insert(:participation, %{read: false, user: user})
    participation2 = insert(:participation, %{read: false, user: user})
    participation3 = insert(:participation, %{read: false, user: other_user})

    {:ok, [%{read: true}, %{read: true}]} = Participation.mark_all_as_read(user)

    assert Participation.get(participation1.id).read == true
    assert Participation.get(participation2.id).read == true
    assert Participation.get(participation3.id).read == false
  end

  test "gets all the participations for a user, ordered by updated at descending" do
    user = insert(:user)
    {:ok, activity_one} = CommonAPI.post(user, %{"status" => "x", "visibility" => "direct"})
    :timer.sleep(1000)
    {:ok, activity_two} = CommonAPI.post(user, %{"status" => "x", "visibility" => "direct"})
    :timer.sleep(1000)

    {:ok, activity_three} =
      CommonAPI.post(user, %{
        "status" => "x",
        "visibility" => "direct",
        "in_reply_to_status_id" => activity_one.id
      })

    assert [participation_one, participation_two] = Participation.for_user(user)

    object2 = Pleroma.Object.normalize(activity_two)
    object3 = Pleroma.Object.normalize(activity_three)

    user = Repo.get(Pleroma.User, user.id)

    assert participation_one.conversation.ap_id == object3.data["context"]
    assert participation_two.conversation.ap_id == object2.data["context"]
    assert participation_one.conversation.users == [user]

    # Pagination
    assert [participation_one] = Participation.for_user(user, %{"limit" => 1})

    assert participation_one.conversation.ap_id == object3.data["context"]

    # With last_activity_id
    assert [participation_one] =
             Participation.for_user_with_last_activity_id(user, %{"limit" => 1})

    assert participation_one.last_activity_id == activity_three.id
  end

  test "Doesn't die when the conversation gets empty" do
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{"status" => ".", "visibility" => "direct"})
    [participation] = Participation.for_user_with_last_activity_id(user)

    assert participation.last_activity_id == activity.id

    {:ok, _} = CommonAPI.delete(activity.id, user)

    [] = Participation.for_user_with_last_activity_id(user)
  end

  test "it sets recipients, always keeping the owner of the participation even when not explicitly set" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, _activity} = CommonAPI.post(user, %{"status" => ".", "visibility" => "direct"})
    [participation] = Participation.for_user_with_last_activity_id(user)

    participation = Repo.preload(participation, :recipients)
    user = User.get_cached_by_id(user.id)

    assert participation.recipients |> length() == 1
    assert user in participation.recipients

    {:ok, participation} = Participation.set_recipients(participation, [other_user.id])

    assert participation.recipients |> length() == 2
    assert user in participation.recipients
    assert other_user in participation.recipients
  end
end
