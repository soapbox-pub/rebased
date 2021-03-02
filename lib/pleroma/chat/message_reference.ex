# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Chat.MessageReference do
  @moduledoc """
  A reference that builds a relation between an AP chat message that a user can see and whether it has been seen
  by them, or should be displayed to them. Used to build the chat view that is presented to the user.
  """

  use Ecto.Schema

  alias Pleroma.Chat
  alias Pleroma.Object
  alias Pleroma.Repo

  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, FlakeId.Ecto.Type, autogenerate: true}

  schema "chat_message_references" do
    belongs_to(:object, Object)
    belongs_to(:chat, Chat, type: FlakeId.Ecto.CompatType)

    field(:unread, :boolean, default: true)

    timestamps()
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:object_id, :chat_id, :unread])
    |> validate_required([:object_id, :chat_id, :unread])
  end

  def get_by_id(id) do
    __MODULE__
    |> Repo.get(id)
    |> Repo.preload(:object)
  end

  def delete(cm_ref) do
    cm_ref
    |> Repo.delete()
  end

  def delete_for_object(%{id: object_id}) do
    from(cr in __MODULE__,
      where: cr.object_id == ^object_id
    )
    |> Repo.delete_all()
  end

  def for_chat_and_object(%{id: chat_id}, %{id: object_id}) do
    __MODULE__
    |> Repo.get_by(chat_id: chat_id, object_id: object_id)
    |> Repo.preload(:object)
  end

  def for_chat_query(chat) do
    from(cr in __MODULE__,
      where: cr.chat_id == ^chat.id,
      order_by: [desc: :id],
      preload: [:object]
    )
  end

  def last_message_for_chat(chat) do
    chat
    |> for_chat_query()
    |> limit(1)
    |> Repo.one()
  end

  def create(chat, object, unread) do
    params = %{
      chat_id: chat.id,
      object_id: object.id,
      unread: unread
    }

    %__MODULE__{}
    |> changeset(params)
    |> Repo.insert()
  end

  def unread_count_for_chat(chat) do
    chat
    |> for_chat_query()
    |> where([cmr], cmr.unread == true)
    |> Repo.aggregate(:count)
  end

  def mark_as_read(cm_ref) do
    cm_ref
    |> changeset(%{unread: false})
    |> Repo.update()
  end

  def set_all_seen_for_chat(chat, last_read_id \\ nil) do
    query =
      chat
      |> for_chat_query()
      |> exclude(:order_by)
      |> exclude(:preload)
      |> where([cmr], cmr.unread == true)

    if last_read_id do
      query
      |> where([cmr], cmr.id <= ^last_read_id)
    else
      query
    end
    |> Repo.update_all(set: [unread: false])
  end
end
