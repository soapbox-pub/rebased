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
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    belongs_to(:conversation, Conversation)
    field(:read, :boolean, default: false)
    field(:last_activity_id, FlakeId.Ecto.CompatType, virtual: true)

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

  def mark_as_read(%User{} = user, %Conversation{} = conversation) do
    with %__MODULE__{} = participation <- for_user_and_conversation(user, conversation) do
      mark_as_read(participation)
    end
  end

  def mark_as_read(participation) do
    participation
    |> read_cng(%{read: true})
    |> Repo.update()
    |> case do
      {:ok, participation} ->
        participation = Repo.preload(participation, :user)
        User.set_unread_conversation_count(participation.user)
        {:ok, participation}

      error ->
        error
    end
  end

  def mark_all_as_read(user) do
    {_, participations} =
      __MODULE__
      |> where([p], p.user_id == ^user.id)
      |> where([p], not p.read)
      |> update([p], set: [read: true])
      |> select([p], p)
      |> Repo.update_all([])

    User.set_unread_conversation_count(user)
    {:ok, participations}
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

  def get(_, _ \\ [])
  def get(nil, _), do: nil

  def get(id, params) do
    query =
      if preload = params[:preload] do
        from(p in __MODULE__,
          preload: ^preload
        )
      else
        __MODULE__
      end

    Repo.get(query, id)
  end

  def set_recipients(participation, user_ids) do
    user_ids =
      [participation.user_id | user_ids]
      |> Enum.uniq()

    Repo.transaction(fn ->
      query =
        from(r in RecipientShip,
          where: r.participation_id == ^participation.id
        )

      Repo.delete_all(query)

      users =
        from(u in User,
          where: u.id in ^user_ids
        )
        |> Repo.all()

      RecipientShip.create(users, participation)
      :ok
    end)

    {:ok, Repo.preload(participation, :recipients, force: true)}
  end

  def unread_conversation_count_for_user(user) do
    from(p in __MODULE__,
      where: p.user_id == ^user.id,
      where: not p.read,
      select: %{count: count(p.id)}
    )
  end
end
