# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Chat do
  use Ecto.Schema

  import Ecto.Changeset

  alias Pleroma.Repo
  alias Pleroma.User

  @moduledoc """
  Chat keeps a reference to ChatMessage conversations between a user and an recipient. The recipient can be a user (for now) or a group (not implemented yet).

  It is a helper only, to make it easy to display a list of chats with other people, ordered by last bump. The actual messages are retrieved by querying the recipients of the ChatMessages.
  """

  @primary_key {:id, FlakeId.Ecto.CompatType, autogenerate: true}

  schema "chats" do
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    field(:recipient, :string)

    timestamps()
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:user_id, :recipient])
    |> validate_change(:recipient, fn
      :recipient, recipient ->
        case User.get_cached_by_ap_id(recipient) do
          nil -> [recipient: "must be an existing user"]
          _ -> []
        end
    end)
    |> validate_required([:user_id, :recipient])
    |> unique_constraint(:user_id, name: :chats_user_id_recipient_index)
  end

  def get_by_id(id) do
    __MODULE__
    |> Repo.get(id)
  end

  def get(user_id, recipient) do
    __MODULE__
    |> Repo.get_by(user_id: user_id, recipient: recipient)
  end

  def get_or_create(user_id, recipient) do
    %__MODULE__{}
    |> changeset(%{user_id: user_id, recipient: recipient})
    |> Repo.insert(
      # Need to set something, otherwise we get nothing back at all
      on_conflict: [set: [recipient: recipient]],
      returning: true,
      conflict_target: [:user_id, :recipient]
    )
  end

  def bump_or_create(user_id, recipient) do
    %__MODULE__{}
    |> changeset(%{user_id: user_id, recipient: recipient})
    |> Repo.insert(
      on_conflict: [set: [updated_at: NaiveDateTime.utc_now()]],
      returning: true,
      conflict_target: [:user_id, :recipient]
    )
  end
end
