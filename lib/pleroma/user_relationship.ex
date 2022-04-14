# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.UserRelationship do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Ecto.Changeset
  alias Pleroma.FollowingRelationship
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.UserRelationship

  schema "user_relationships" do
    belongs_to(:source, User, type: FlakeId.Ecto.CompatType)
    belongs_to(:target, User, type: FlakeId.Ecto.CompatType)
    field(:relationship_type, Pleroma.UserRelationship.Type)

    timestamps(updated_at: false)
  end

  for relationship_type <- Keyword.keys(Pleroma.UserRelationship.Type.__enum_map__()) do
    # `def create_block/2`, `def create_mute/2`, `def create_reblog_mute/2`,
    #   `def create_notification_mute/2`, `def create_inverse_subscription/2`,
    #   `def endorsement/2`
    def unquote(:"create_#{relationship_type}")(source, target),
      do: create(unquote(relationship_type), source, target)

    # `def delete_block/2`, `def delete_mute/2`, `def delete_reblog_mute/2`,
    #   `def delete_notification_mute/2`, `def delete_inverse_subscription/2`,
    #   `def delete_endorsement/2`
    def unquote(:"delete_#{relationship_type}")(source, target),
      do: delete(unquote(relationship_type), source, target)

    # `def block_exists?/2`, `def mute_exists?/2`, `def reblog_mute_exists?/2`,
    #   `def notification_mute_exists?/2`, `def inverse_subscription_exists?/2`,
    #   `def inverse_endorsement?/2`
    def unquote(:"#{relationship_type}_exists?")(source, target),
      do: exists?(unquote(relationship_type), source, target)
  end

  def user_relationship_types, do: Keyword.keys(user_relationship_mappings())

  def user_relationship_mappings, do: Pleroma.UserRelationship.Type.__enum_map__()

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

  def dictionary(
        _source_users,
        _target_users,
        [] = _source_to_target_rel_types,
        [] = _target_to_source_rel_types
      ) do
    []
  end

  def dictionary(
        source_users,
        target_users,
        source_to_target_rel_types,
        target_to_source_rel_types
      )
      when is_list(source_users) and is_list(target_users) do
    source_user_ids = User.binary_id(source_users)
    target_user_ids = User.binary_id(target_users)

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

  def exists?(dictionary, rel_type, source, target, func) do
    cond do
      is_nil(source) or is_nil(target) ->
        false

      dictionary ->
        [rel_type, source.id, target.id] in dictionary

      true ->
        func.(source, target)
    end
  end

  @doc ":relationships option for StatusView / AccountView / NotificationView"
  def view_relationships_option(reading_user, actors, opts \\ [])

  def view_relationships_option(nil = _reading_user, _actors, _opts) do
    %{user_relationships: [], following_relationships: []}
  end

  def view_relationships_option(%User{} = reading_user, actors, opts) do
    {source_to_target_rel_types, target_to_source_rel_types} =
      case opts[:subset] do
        :source_mutes ->
          # Used for statuses rendering (FE needs `muted` flag for each status when statuses load)
          {[:mute], []}

        nil ->
          {[:block, :mute, :notification_mute, :reblog_mute], [:block, :inverse_subscription]}

        unknown ->
          raise "Unsupported :subset option value: #{inspect(unknown)}"
      end

    user_relationships =
      UserRelationship.dictionary(
        [reading_user],
        actors,
        source_to_target_rel_types,
        target_to_source_rel_types
      )

    following_relationships =
      case opts[:subset] do
        :source_mutes ->
          []

        nil ->
          FollowingRelationship.all_between_user_sets([reading_user], actors)

        unknown ->
          raise "Unsupported :subset option value: #{inspect(unknown)}"
      end

    %{user_relationships: user_relationships, following_relationships: following_relationships}
  end

  defp validate_not_self_relationship(%Changeset{} = changeset) do
    changeset
    |> validate_source_id_target_id_inequality()
    |> validate_target_id_source_id_inequality()
  end

  defp validate_source_id_target_id_inequality(%Changeset{} = changeset) do
    validate_change(changeset, :source_id, fn _, source_id ->
      if source_id == get_field(changeset, :target_id) do
        [source_id: "can't be equal to target_id"]
      else
        []
      end
    end)
  end

  defp validate_target_id_source_id_inequality(%Changeset{} = changeset) do
    validate_change(changeset, :target_id, fn _, target_id ->
      if target_id == get_field(changeset, :source_id) do
        [target_id: "can't be equal to source_id"]
      else
        []
      end
    end)
  end
end
