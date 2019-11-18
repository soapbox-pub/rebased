# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.UserRelationship do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.UserRelationship

  schema "user_relationships" do
    belongs_to(:source, User, type: FlakeId.Ecto.CompatType)
    belongs_to(:target, User, type: FlakeId.Ecto.CompatType)
    field(:relationship_type, UserRelationshipTypeEnum)

    timestamps(updated_at: false)
  end

  def changeset(%UserRelationship{} = user_relationship, params \\ %{}) do
    user_relationship
    |> cast(params, [:relationship_type, :source_id, :target_id])
    |> validate_required([:relationship_type, :source_id, :target_id])
    |> unique_constraint(:relationship_type,
      name: :user_relationships_source_id_relationship_type_target_id_index
    )
    |> validate_not_self_relationship()
  end

  def exists?(relationship_type, %User{} = source, %User{} = target) do
    UserRelationship
    |> where(relationship_type: ^relationship_type, source_id: ^source.id, target_id: ^target.id)
    |> Repo.exists?()
  end

  def block_exists?(%User{} = blocker, %User{} = blockee), do: exists?(:block, blocker, blockee)

  def mute_exists?(%User{} = muter, %User{} = mutee), do: exists?(:mute, muter, mutee)

  def create(relationship_type, %User{} = source, %User{} = target) do
    %UserRelationship{}
    |> changeset(%{
      relationship_type: relationship_type,
      source_id: source.id,
      target_id: target.id
    })
    |> Repo.insert(
      on_conflict: :replace_all_except_primary_key,
      conflict_target: [:source_id, :relationship_type, :target_id]
    )
  end

  def create_block(%User{} = blocker, %User{} = blockee), do: create(:block, blocker, blockee)

  def create_mute(%User{} = muter, %User{} = mutee), do: create(:mute, muter, mutee)

  def delete(relationship_type, %User{} = source, %User{} = target) do
    attrs = %{relationship_type: relationship_type, source_id: source.id, target_id: target.id}

    case Repo.get_by(UserRelationship, attrs) do
      %UserRelationship{} = existing_record -> Repo.delete(existing_record)
      nil -> {:ok, nil}
    end
  end

  def delete_block(%User{} = blocker, %User{} = blockee), do: delete(:block, blocker, blockee)

  def delete_mute(%User{} = muter, %User{} = mutee), do: delete(:mute, muter, mutee)

  defp validate_not_self_relationship(%Ecto.Changeset{} = changeset) do
    changeset
    |> validate_change(:target_id, fn _, target_id ->
      if target_id == get_field(changeset, :source_id) do
        [target_id: "can't be equal to source_id"]
      else
        []
      end
    end)
    |> validate_change(:source_id, fn _, source_id ->
      if source_id == get_field(changeset, :target_id) do
        [source_id: "can't be equal to target_id"]
      else
        []
      end
    end)
  end
end
