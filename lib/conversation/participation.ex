# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Conversation.Participation do
  use Ecto.Schema
  alias Pleroma.User
  alias Pleroma.Conversation
  alias Pleroma.Repo
  alias Pleroma.Web.ActivityPub.ActivityPub
  import Ecto.Changeset
  import Ecto.Query

  schema "conversation_participations" do
    belongs_to(:user, User, type: Pleroma.FlakeId)
    belongs_to(:conversation, Conversation)
    field(:read, :boolean, default: false)
    field(:last_activity_id, Pleroma.FlakeId, virtual: true)

    timestamps()
  end

  def creation_cng(struct, params) do
    struct
    |> cast(params, [:user_id, :conversation_id])
    |> validate_required([:user_id, :conversation_id])
  end

  def create_for_user_and_conversation(user, conversation) do
    %__MODULE__{}
    |> creation_cng(%{user_id: user.id, conversation_id: conversation.id})
    |> Repo.insert(
      on_conflict: [set: [read: false, updated_at: NaiveDateTime.utc_now()]],
      returning: true,
      conflict_target: [:user_id, :conversation_id]
    )
  end

  def read_cng(struct, params) do
    struct
    |> cast(params, [:read])
    |> validate_required([:read])
  end

  def mark_as_read(participation) do
    participation
    |> read_cng(%{read: true})
    |> Repo.update()
  end

  def mark_as_unread(participation) do
    participation
    |> read_cng(%{read: false})
    |> Repo.update()
  end

  def for_user(user, params \\ %{}) do
    from(p in __MODULE__,
      where: p.user_id == ^user.id,
      order_by: [desc: p.updated_at]
    )
    |> Pleroma.Pagination.fetch_paginated(params)
  end

  def for_user_with_last_activity_id(user, params \\ %{}) do
    for_user(user, params)
    |> Repo.preload(:conversation)
    |> Enum.map(fn participation ->
      # TODO: Don't load all those activities, just get the most recent
      # Involves splitting up the query.
      activities =
        ActivityPub.fetch_activities_for_context(participation.conversation.ap_id, %{
          "user" => user,
          "blocking_user" => user
        })

      activity_id =
        case activities do
          [activity | _] -> activity.id
          _ -> nil
        end

      %{
        participation
        | last_activity_id: activity_id
      }
    end)
  end
end
