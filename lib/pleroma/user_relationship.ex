# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.UserRelationship do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias FlakeId.Ecto.CompatType
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.UserRelationship

  schema "user_relationships" do
    belongs_to(:source, User, type: FlakeId.Ecto.CompatType)
    belongs_to(:target, User, type: FlakeId.Ecto.CompatType)
    field(:relationship_type, UserRelationshipTypeEnum)

    timestamps(updated_at: false)
  end

  for relationship_type <- Keyword.keys(UserRelationshipTypeEnum.__enum_map__()) do
    # Definitions of `create_block/2`, `create_mute/2` etc.
    def unquote(:"create_#{relationship_type}")(source, target),
      do: create(unquote(relationship_type), source, target)

    # Definitions of `delete_block/2`, `delete_mute/2` etc.
    def unquote(:"delete_#{relationship_type}")(source, target),
      do: delete(unquote(relationship_type), source, target)

    # Definitions of `block_exists?/2`, `mute_exists?/2` etc.
    def unquote(:"#{relationship_type}_exists?")(source, target),
      do: exists?(unquote(relationship_type), source, target)
  end

  def user_relationship_types, do: Keyword.keys(user_relationship_mappings())

  def user_relationship_mappings, do: UserRelationshipTypeEnum.__enum_map__()

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

  def create(relationship_type, %User{} = source, %User{} = target) do
    %UserRelationship{}
    |> changeset(%{
      relationship_type: relationship_type,
      source_id: source.id,
      target_id: target.id
    })
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: [:source_id, :relationship_type, :target_id]
    )
  end

  def delete(relationship_type, %User{} = source, %User{} = target) do
    attrs = %{relationship_type: relationship_type, source_id: source.id, target_id: target.id}

    case Repo.get_by(UserRelationship, attrs) do
      %UserRelationship{} = existing_record -> Repo.delete(existing_record)
      nil -> {:ok, nil}
    end
  end

  def dictionary(
        source_users,
        target_users,
        source_to_target_rel_types \\ nil,
        target_to_source_rel_types \\ nil
      )
      when is_list(source_users) and is_list(target_users) do
    get_bin_ids = fn user ->
      with {:ok, bin_id} <- CompatType.dump(user.id), do: bin_id
    end

    source_user_ids = Enum.map(source_users, &get_bin_ids.(&1))
    target_user_ids = Enum.map(target_users, &get_bin_ids.(&1))

    get_rel_type_codes = fn rel_type -> user_relationship_mappings()[rel_type] end

    source_to_target_rel_types =
      Enum.map(source_to_target_rel_types || user_relationship_types(), &get_rel_type_codes.(&1))

    target_to_source_rel_types =
      Enum.map(target_to_source_rel_types || user_relationship_types(), &get_rel_type_codes.(&1))

    __MODULE__
    |> where(
      fragment(
        "(source_id = ANY(?) AND target_id = ANY(?) AND relationship_type = ANY(?)) OR \
        (source_id = ANY(?) AND target_id = ANY(?) AND relationship_type = ANY(?))",
        ^source_user_ids,
        ^target_user_ids,
        ^source_to_target_rel_types,
        ^target_user_ids,
        ^source_user_ids,
        ^target_to_source_rel_types
      )
    )
    |> select([ur], [ur.relationship_type, ur.source_id, ur.target_id])
    |> Repo.all()
  end

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
