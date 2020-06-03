# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ChatMessageReference do
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

  @primary_key {:id, FlakeId.Ecto.CompatType, autogenerate: true}

  schema "chat_message_references" do
    belongs_to(:object, Object)
    belongs_to(:chat, Chat)

    field(:seen, :boolean, default: false)

    timestamps()
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:object_id, :chat_id, :seen])
    |> validate_required([:object_id, :chat_id, :seen])
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

  def create(chat, object, seen) do
    params = %{
      chat_id: chat.id,
      object_id: object.id,
      seen: seen
    }

    %__MODULE__{}
    |> changeset(params)
    |> Repo.insert()
  end
end
