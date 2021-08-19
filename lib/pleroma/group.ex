# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Group do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Pleroma.Activity
  alias Pleroma.Group
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.UserRelationship
  alias Pleroma.Web.ActivityPub
  alias Pleroma.Web.Endpoint

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

    field(:ap_id, :string)
    field(:name, :string)
    field(:description, :string)
    field(:privacy, :string, default: "public")
    field(:members_collection, :string)
    field(:accepts_joins, :boolean, default: false)

    timestamps()
  end

  @spec create(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create(params) do
    with {:ok, %User{id: user_id, ap_id: ap_id}} <- generate_user(params) do
      %__MODULE__{ap_id: ap_id, user_id: user_id, members_collection: "#{ap_id}/members"}
      |> changeset(params)
      |> Repo.insert()
    end
  end

  def get_by_id(id) do
    Repo.get(Group, id)
  end

  def get_by_ap_id(ap_id) do
    Repo.get_by(Group, ap_id: ap_id)
  end

  def get_by_slug(slug) do
    User
    |> where(nickname: ^slug)
    |> preload(:group)
    |> Repo.one()
    |> case do
      %User{group: %Group{} = group} -> group
      error -> error
    end
  end

  def get_by_slug_or_id(id) do
    unless FlakeId.flake_id?(id) do
      get_by_slug(id)
    else
      get_by_id(id) || get_by_slug(id)
    end
  end

  def get_all_by_ids(ids) do
    from(g in __MODULE__, where: g.id in ^ids)
    |> Repo.all()
  end

  def get_by_user(%User{group: %Group{} = group}), do: group
  def get_by_user(%User{} = user), do: Repo.preload(user, :group).group

  defp generate_ap_id(slug) do
    "#{Endpoint.url()}/groups/#{slug}"
  end

  defp generate_user(%{slug: slug}) when is_binary(slug) do
    ap_id = generate_ap_id(slug)

    %{
      ap_id: ap_id,
      nickname: slug,
      follower_address: "#{ap_id}/followers",
      following_address: "#{ap_id}/following",
      local: true,
      accepts_chat_messages: false
    }
    |> User.group_changeset()
    |> Repo.insert()
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [
      :ap_id,
      :user_id,
      :owner_id,
      :name,
      :description,
      :privacy,
      :members_collection
    ])
    |> validate_required([:ap_id, :user_id, :owner_id, :members_collection])
  end

  def is_local?(%Group{} = group) do
    case Repo.preload(group, :user) do
      %Group{user: %User{local: local}} -> local
      _ -> false
    end
  end

  def is_member?(%{user_id: user_id}, %User{} = member) do
    UserRelationship.membership_exists?(%User{id: user_id}, member)
  end

  def is_member?(%Group{} = group, ap_id) when is_binary(ap_id) do
    with %User{} = user <- User.get_cached_by_ap_id(ap_id) do
      is_member?(group, user)
    else
      _ -> false
    end
  end

  def is_member?(_group, _member), do: false

  def members(group) do
    Repo.preload(group, :members).members
  end

  def get_members_query(%Group{} = group) do
    Ecto.assoc(group, :members)
  end

  def get_external_members(%Group{} = group) do
    group
    |> get_members_query()
    |> where([u], u.local == false)
    |> Repo.all()
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
    get_by_ap_id(id)
  end

  def get_for_object(%{"type" => "Create", "object" => object}), do: get_for_object(object)
  def get_for_object(_), do: nil

  @spec get_object_group(object :: map()) :: t() | nil
  def get_object_group(object) do
    with %Object{data: %{"to" => to}} when is_list(to) <- Object.normalize(object) do
      Enum.find_value(to, fn address -> Group.get_by_ap_id(address) end)
    else
      _ -> nil
    end
  end

  def get_membership_state(%Group{} = group, %User{} = user) do
    if is_member?(group, user) do
      :join_accept
    else
      with %Activity{data: %{"state" => state}} <-
             ActivityPub.Utils.fetch_latest_join(user, group) do
        case state do
          "accept" -> :join_accept
          "reject" -> :join_reject
          _ -> :join_pending
        end
      end
    end
  end
end
