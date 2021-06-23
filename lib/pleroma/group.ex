# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Group do
  use Ecto.Schema

  import Ecto.Changeset

  alias Pleroma.User
  alias Pleroma.Repo
  alias Pleroma.Web.Endpoint
  alias Pleroma.UserRelationship

  @moduledoc """
  Groups contain all the additional information about a group that's not stored
  in the user table.

  Concepts:

  - Groups have an owner
  - Groups have members, invited by the owner.
  """

  @type t :: %__MODULE__{}
  @primary_key {:id, FlakeId.Ecto.CompatType, autogenerate: true}

  schema "groups" do
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    belongs_to(:owner, User, type: FlakeId.Ecto.CompatType, foreign_key: :owner_id)

    has_many(:members, through: [:user, :group_members])

    field(:name, :string)
    field(:privacy, Ecto.Enum, values: [:public, :members_only], null: false)
    field(:description, :string)
    field(:members_collection, :string)

    timestamps()
  end

  @spec create(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create(params) do
    with {:ok, user} <- generate_user(params) do
      %__MODULE__{user_id: user.id, members_collection: "#{user.ap_id}/members"}
      |> changeset(params)
      |> Repo.insert()
    end
  end

  defp generate_ap_id(slug) do
    "#{Endpoint.url()}/groups/#{slug}"
  end

  defp generate_user(%{slug: slug}) when is_binary(slug) do
    ap_id = generate_ap_id(slug)

    %{
      ap_id: ap_id,
      name: slug,
      nickname: slug,
      follower_address: "#{ap_id}/followers",
      following_address: "#{ap_id}/following",
      local: true
    }
    |> User.group_changeset()
    |> Repo.insert()
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:user_id, :owner_id, :name, :description, :members_collection])
    |> validate_required([:user_id, :owner_id, :members_collection])
  end

  def is_member?(%{user_id: user_id}, member) do
    UserRelationship.membership_exists?(%User{id: user_id}, member)
  end

  def members(group) do
    Repo.preload(group, :members).members
  end

  def add_member(%{user_id: user_id} = group, member) do
    with {:ok, _relationship} <- UserRelationship.create_membership(%User{id: user_id}, member) do
      {:ok, group}
    end
  end

  def remove_member(%{user_id: user_id} = group, member) do
    with {:ok, _relationship} <- UserRelationship.delete_membership(%User{id: user_id}, member) do
      {:ok, group}
    end
  end

  @spec get_for_object(map()) :: t() | nil
  def get_for_object(%{"type" => "Group", "id" => id}) do
    with %User{} = user <- User.get_cached_by_ap_id(id),
         group <- Repo.preload(user, :group).group do
      group
    end
  end

  def get_for_object(%{"type" => "Create", "object" => object}), do: get_for_object(object)
  def get_for_object(_), do: nil
end
