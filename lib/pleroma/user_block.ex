# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.UserBlock do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.UserBlock

  schema "user_blocks" do
    belongs_to(:blocker, User, type: FlakeId.Ecto.CompatType)
    belongs_to(:blockee, User, type: FlakeId.Ecto.CompatType)

    timestamps(updated_at: false)
  end

  def changeset(%UserBlock{} = user_block, params \\ %{}) do
    user_block
    |> cast(params, [:blocker_id, :blockee_id])
    |> validate_required([:blocker_id, :blockee_id])
    |> unique_constraint(:blockee_id, name: :user_blocks_blocker_id_blockee_id_index)
    |> validate_not_self_block()
  end

  def exists?(%User{} = blocker, %User{} = blockee) do
    UserBlock
    |> where(blocker_id: ^blocker.id, blockee_id: ^blockee.id)
    |> Repo.exists?()
  end

  def create(%User{} = blocker, %User{} = blockee) do
    %UserBlock{}
    |> changeset(%{blocker_id: blocker.id, blockee_id: blockee.id})
    |> Repo.insert(
      on_conflict: :replace_all_except_primary_key,
      conflict_target: [:blocker_id, :blockee_id]
    )
  end

  def delete(%User{} = blocker, %User{} = blockee) do
    attrs = %{blocker_id: blocker.id, blockee_id: blockee.id}

    if is_nil(existing_record = Repo.get_by(UserBlock, attrs)) do
      {:ok, nil}
    else
      Repo.delete(existing_record)
    end
  end

  defp validate_not_self_block(%Ecto.Changeset{} = changeset) do
    changeset
    |> validate_change(:blockee_id, fn _, blockee_id ->
      if blockee_id == changeset.changes[:blocker_id] || changeset.data.blocker_id do
        [blockee_id: "can't be equal to blocker_id"]
      else
        []
      end
    end)
    |> validate_change(:blocker_id, fn _, blocker_id ->
      if blocker_id == changeset.changes[:blockee_id] || changeset.data.blockee_id do
        [blocker_id: "can't be equal to blockee_id"]
      else
        []
      end
    end)
  end
end
