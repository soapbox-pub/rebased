# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Conversation.Participation do
  use Ecto.Schema
  alias Pleroma.Conversation
  alias Pleroma.Conversation.Participation.RecipientShip
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  import Ecto.Changeset
  import Ecto.Query

  schema "conversation_participations" do
    belongs_to(:user, User, type: Pleroma.FlakeId)
    belongs_to(:conversation, Conversation)
    field(:read, :boolean, default: false)
    field(:last_activity_id, Pleroma.FlakeId, virtual: true)

    has_many(:recipient_ships, RecipientShip)
    has_many(:recipients, through: [:recipient_ships, :user])

    timestamps()
  end

  def creation_cng(struct, params) do
    struct
    |> cast(params, [:user_id, :conversation_id, :read])
    |> validate_required([:user_id, :conversation_id])
  end

  def create_for_user_and_conversation(user, conversation, opts \\ []) do
    read = !!opts[:read]

    %__MODULE__{}
    |> creation_cng(%{user_id: user.id, conversation_id: conversation.id, read: read})
    |> Repo.insert(
      on_conflict: [set: [read: read, updated_at: NaiveDateTime.utc_now()]],
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
      order_by: [desc: p.updated_at],
      preload: [conversation: [:users]]
    )
    |> Pleroma.Pagination.fetch_paginated(params)
  end

  def for_user_and_conversation(user, conversation) do
    from(p in __MODULE__,
      where: p.user_id == ^user.id,
      where: p.conversation_id == ^conversation.id
    )
    |> Repo.one()
  end

  def for_user_with_last_activity_id(user, params \\ %{}) do
    for_user(user, params)
    |> Enum.map(fn participation ->
      activity_id =
        ActivityPub.fetch_latest_activity_id_for_context(participation.conversation.ap_id, %{
          "user" => user,
          "blocking_user" => user
        })

      %{
        participation
        | last_activity_id: activity_id
      }
    end)
    |> Enum.filter(& &1.last_activity_id)
  end
end
