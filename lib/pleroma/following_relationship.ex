# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.FollowingRelationship do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias FlakeId.Ecto.CompatType
  alias Pleroma.Repo
  alias Pleroma.User

  schema "following_relationships" do
    field(:state, FollowingRelationshipStateEnum, default: :follow_pending)

    belongs_to(:follower, User, type: CompatType)
    belongs_to(:following, User, type: CompatType)

    timestamps()
  end

  def changeset(%__MODULE__{} = following_relationship, attrs) do
    following_relationship
    |> cast(attrs, [:state])
    |> put_assoc(:follower, attrs.follower)
    |> put_assoc(:following, attrs.following)
    |> validate_required([:state, :follower, :following])
    |> unique_constraint(:follower_id,
      name: :following_relationships_follower_id_following_id_index
    )
    |> validate_not_self_relationship()
  end

  def state_to_enum(state) when is_binary(state) do
    case state do
      "pending" -> :follow_pending
      "accept" -> :follow_accept
      "reject" -> :follow_reject
      _ -> raise "State is not convertible to FollowingRelationshipStateEnum: #{state}"
    end
  end

  def get(%User{} = follower, %User{} = following) do
    __MODULE__
    |> where(follower_id: ^follower.id, following_id: ^following.id)
    |> Repo.one()
  end

  def update(follower, following, :follow_reject), do: unfollow(follower, following)

  def update(%User{} = follower, %User{} = following, state) do
    case get(follower, following) do
      nil ->
        follow(follower, following, state)

      following_relationship ->
        following_relationship
        |> cast(%{state: state}, [:state])
        |> validate_required([:state])
        |> Repo.update()
    end
  end

  def follow(%User{} = follower, %User{} = following, state \\ :follow_accept) do
    %__MODULE__{}
    |> changeset(%{follower: follower, following: following, state: state})
    |> Repo.insert(on_conflict: :nothing)
  end

  def unfollow(%User{} = follower, %User{} = following) do
    case get(follower, following) do
      %__MODULE__{} = following_relationship -> Repo.delete(following_relationship)
      _ -> {:ok, nil}
    end
  end

  def follower_count(%User{} = user) do
    %{followers: user, deactivated: false}
    |> User.Query.build()
    |> Repo.aggregate(:count, :id)
  end

  def following_count(%User{id: nil}), do: 0

  def following_count(%User{} = user) do
    %{friends: user, deactivated: false}
    |> User.Query.build()
    |> Repo.aggregate(:count, :id)
  end

  def get_follow_requests(%User{id: id}) do
    __MODULE__
    |> join(:inner, [r], f in assoc(r, :follower))
    |> where([r], r.state == ^:follow_pending)
    |> where([r], r.following_id == ^id)
    |> select([r, f], f)
    |> Repo.all()
  end

  def following?(%User{id: follower_id}, %User{id: followed_id}) do
    __MODULE__
    |> where(follower_id: ^follower_id, following_id: ^followed_id, state: ^:follow_accept)
    |> Repo.exists?()
  end

  def following(%User{} = user) do
    following =
      __MODULE__
      |> join(:inner, [r], u in User, on: r.following_id == u.id)
      |> where([r], r.follower_id == ^user.id)
      |> where([r], r.state == ^:follow_accept)
      |> select([r, u], u.follower_address)
      |> Repo.all()

    if not user.local or user.invisible do
      following
    else
      [user.follower_address | following]
    end
  end

  def move_following(origin, target) do
    __MODULE__
    |> join(:inner, [r], f in assoc(r, :follower))
    |> where(following_id: ^origin.id)
    |> where([r, f], f.allow_following_move == true)
    |> limit(50)
    |> preload([:follower])
    |> Repo.all()
    |> Enum.map(fn following_relationship ->
      Repo.delete(following_relationship)
      Pleroma.Web.CommonAPI.follow(following_relationship.follower, target)
    end)
    |> case do
      [] ->
        User.update_follower_count(origin)
        :ok

      _ ->
        move_following(origin, target)
    end
  end

  def all_between_user_sets(
        source_users,
        target_users
      )
      when is_list(source_users) and is_list(target_users) do
    source_user_ids = User.binary_id(source_users)
    target_user_ids = User.binary_id(target_users)

    __MODULE__
    |> where(
      fragment(
        "(follower_id = ANY(?) AND following_id = ANY(?)) OR \
        (follower_id = ANY(?) AND following_id = ANY(?))",
        ^source_user_ids,
        ^target_user_ids,
        ^target_user_ids,
        ^source_user_ids
      )
    )
    |> Repo.all()
  end

  def find(following_relationships, follower, following) do
    Enum.find(following_relationships, fn
      fr -> fr.follower_id == follower.id and fr.following_id == following.id
    end)
  end

  defp validate_not_self_relationship(%Ecto.Changeset{} = changeset) do
    changeset
    |> validate_change(:following_id, fn _, following_id ->
      if following_id == get_field(changeset, :follower_id) do
        [target_id: "can't be equal to follower_id"]
      else
        []
      end
    end)
    |> validate_change(:follower_id, fn _, follower_id ->
      if follower_id == get_field(changeset, :following_id) do
        [source_id: "can't be equal to following_id"]
      else
        []
      end
    end)
  end
end
