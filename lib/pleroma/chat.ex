# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Chat do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Pleroma.Chat
  alias Pleroma.Repo
  alias Pleroma.User

  @moduledoc """
  Chat keeps a reference to ChatMessage conversations between a user and an recipient. The recipient can be a user (for now) or a group (not implemented yet).

  It is a helper only, to make it easy to display a list of chats with other people, ordered by last bump. The actual messages are retrieved by querying the recipients of the ChatMessages.
  """

  @type t :: %__MODULE__{}
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

  @spec get_by_user_and_id(User.t(), FlakeId.Ecto.CompatType.t()) ::
          {:ok, t()} | {:error, :not_found}
  def get_by_user_and_id(%User{id: user_id}, id) do
    from(c in __MODULE__,
      where: c.id == ^id,
      where: c.user_id == ^user_id
    )
    |> Repo.find_resource()
  end

  @spec get_by_id(FlakeId.Ecto.CompatType.t()) :: t() | nil
  def get_by_id(id) do
    Repo.get(__MODULE__, id)
  end

  @spec get(FlakeId.Ecto.CompatType.t(), String.t()) :: t() | nil
  def get(user_id, recipient) do
    Repo.get_by(__MODULE__, user_id: user_id, recipient: recipient)
  end

  @spec get_or_create(FlakeId.Ecto.CompatType.t(), String.t()) ::
          {:ok, t()} | {:error, Ecto.Changeset.t()}
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

  @spec bump_or_create(FlakeId.Ecto.CompatType.t(), String.t()) ::
          {:ok, t()} | {:error, Ecto.Changeset.t()}
  def bump_or_create(user_id, recipient) do
    %__MODULE__{}
    |> changeset(%{user_id: user_id, recipient: recipient})
    |> Repo.insert(
      on_conflict: [set: [updated_at: NaiveDateTime.utc_now()]],
      returning: true,
      conflict_target: [:user_id, :recipient]
    )
  end

  @spec for_user_query(FlakeId.Ecto.CompatType.t()) :: Ecto.Query.t()
  def for_user_query(user_id) do
    from(c in Chat,
      where: c.user_id == ^user_id,
      order_by: [desc: c.updated_at]
    )
  end
end
