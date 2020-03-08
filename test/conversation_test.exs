# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ConversationTest do
  use Pleroma.DataCase
  alias Pleroma.Activity
  alias Pleroma.Conversation
  alias Pleroma.Object
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  clear_config_all([:instance, :federating]) do
    Pleroma.Config.put([:instance, :federating], true)
  end

  test "it goes through old direct conversations" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, _activity} =
      CommonAPI.post(user, %{"visibility" => "direct", "status" => "hey @#{other_user.nickname}"})

    Pleroma.Tests.ObanHelpers.perform_all()

    Repo.delete_all(Conversation)
    Repo.delete_all(Conversation.Participation)

    refute Repo.one(Conversation)

    Conversation.bump_for_all_activities()

    assert Repo.one(Conversation)
    [participation, _p2] = Repo.all(Conversation.Participation)

    assert participation.read
  end

  test "it creates a conversation for given ap_id" do
    assert {:ok, %Conversation{} = conversation} =
             Conversation.create_for_ap_id("https://some_ap_id")

    # Inserting again returns the same
    assert {:ok, conversation_two} = Conversation.create_for_ap_id("https://some_ap_id")
    assert conversation_two.id == conversation.id
  end

  test "public posts don't create conversations" do
    user = insert(:user)
    {:ok, activity} = CommonAPI.post(user, %{"status" => "Hey"})

    object = Pleroma.Object.normalize(activity)
    context = object.data["context"]

    conversation = Conversation.get_for_ap_id(context)

    refute conversation
  end

  test "it creates or updates a conversation and participations for a given DM" do
    har = insert(:user)
    jafnhar = insert(:user, local: false)
    tridi = insert(:user)

    {:ok, activity} =
      CommonAPI.post(har, %{"status" => "Hey @#{jafnhar.nickname}", "visibility" => "direct"})

    object = Pleroma.Object.normalize(activity)
    context = object.data["context"]

    conversation =
      Conversation.get_for_ap_id(context)
      |> Repo.preload(:participations)

    assert conversation

    assert Enum.find(conversation.participations, fn %{user_id: user_id} -> har.id == user_id end)

    assert Enum.find(conversation.participations, fn %{user_id: user_id} ->
             jafnhar.id == user_id
           end)

    {:ok, activity} =
      CommonAPI.post(jafnhar, %{
        "status" => "Hey @#{har.nickname}",
        "visibility" => "direct",
        "in_reply_to_status_id" => activity.id
      })

    object = Pleroma.Object.normalize(activity)
    context = object.data["context"]

    conversation_two =
      Conversation.get_for_ap_id(context)
      |> Repo.preload(:participations)

    assert conversation_two.id == conversation.id

    assert Enum.find(conversation_two.participations, fn %{user_id: user_id} ->
             har.id == user_id
           end)

    assert Enum.find(conversation_two.participations, fn %{user_id: user_id} ->
             jafnhar.id == user_id
           end)

    {:ok, activity} =
      CommonAPI.post(tridi, %{
        "status" => "Hey @#{har.nickname}",
        "visibility" => "direct",
        "in_reply_to_status_id" => activity.id
      })

    object = Pleroma.Object.normalize(activity)
    context = object.data["context"]

    conversation_three =
      Conversation.get_for_ap_id(context)
      |> Repo.preload([:participations, :users])

    assert conversation_three.id == conversation.id

    assert Enum.find(conversation_three.participations, fn %{user_id: user_id} ->
             har.id == user_id
           end)

    assert Enum.find(conversation_three.participations, fn %{user_id: user_id} ->
             jafnhar.id == user_id
           end)

    assert Enum.find(conversation_three.participations, fn %{user_id: user_id} ->
             tridi.id == user_id
           end)

    assert Enum.find(conversation_three.users, fn %{id: user_id} ->
             har.id == user_id
           end)

    assert Enum.find(conversation_three.users, fn %{id: user_id} ->
             jafnhar.id == user_id
           end)

    assert Enum.find(conversation_three.users, fn %{id: user_id} ->
             tridi.id == user_id
           end)
  end

  test "create_or_bump_for returns the conversation with participations" do
    har = insert(:user)
    jafnhar = insert(:user, local: false)

    {:ok, activity} =
      CommonAPI.post(har, %{"status" => "Hey @#{jafnhar.nickname}", "visibility" => "direct"})

    {:ok, conversation} = Conversation.create_or_bump_for(activity)

    assert length(conversation.participations) == 2

    {:ok, activity} =
      CommonAPI.post(har, %{"status" => "Hey @#{jafnhar.nickname}", "visibility" => "public"})

    assert {:error, _} = Conversation.create_or_bump_for(activity)
  end

  test "create_or_bump_for does not normalize objects before checking the activity type" do
    note = insert(:note)
    note_id = note.data["id"]
    Repo.delete(note)
    refute Object.get_by_ap_id(note_id)

    Tesla.Mock.mock(fn env ->
      case env.url do
        ^note_id ->
          # TODO: add attributedTo and tag to the note factory
          body =
            note.data
            |> Map.put("attributedTo", note.data["actor"])
            |> Map.put("tag", [])
            |> Jason.encode!()

          %Tesla.Env{status: 200, body: body}
      end
    end)

    undo = %Activity{
      id: "fake",
      data: %{
        "id" => Pleroma.Web.ActivityPub.Utils.generate_activity_id(),
        "actor" => note.data["actor"],
        "to" => [note.data["actor"]],
        "object" => note_id,
        "type" => "Undo"
      }
    }

    Conversation.create_or_bump_for(undo)

    refute Object.get_by_ap_id(note_id)
  end
end
