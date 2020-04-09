# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Chat do
  use Ecto.Schema
  import Ecto.Changeset

  alias Pleroma.User
  alias Pleroma.Repo

  @moduledoc """
  Chat keeps a reference to ChatMessage conversations between a user and an recipient. The recipient can be a user (for now) or a group (not implemented yet).

  It is a helper only, to make it easy to display a list of chats with other people, ordered by last bump. The actual messages are retrieved by querying the recipients of the ChatMessages.
  """

  schema "chats" do
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    field(:recipient, :string)
    field(:unread, :integer, default: 0, read_after_writes: true)

    timestamps()
  end

  def creation_cng(struct, params) do
    struct
    |> cast(params, [:user_id, :recipient, :unread])
    |> validate_required([:user_id, :recipient])
    |> unique_constraint(:user_id, name: :chats_user_id_recipient_index)
  end

  def get(user_id, recipient) do
    __MODULE__
    |> Repo.get_by(user_id: user_id, recipient: recipient)
  end

  def get_or_create(user_id, recipient) do
    %__MODULE__{}
    |> creation_cng(%{user_id: user_id, recipient: recipient})
    |> Repo.insert(
      on_conflict: :nothing,
      returning: true,
      conflict_target: [:user_id, :recipient]
    )
  end

  def bump_or_create(user_id, recipient) do
    %__MODULE__{}
    |> creation_cng(%{user_id: user_id, recipient: recipient, unread: 1})
    |> Repo.insert(
      on_conflict: [set: [updated_at: NaiveDateTime.utc_now()], inc: [unread: 1]],
      conflict_target: [:user_id, :recipient]
    )
  end
end
