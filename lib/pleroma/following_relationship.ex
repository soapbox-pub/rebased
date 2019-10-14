# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.FollowingRelationship do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias FlakeId.Ecto.CompatType
  alias Pleroma.Repo
  alias Pleroma.User

  schema "following_relationships" do
    field(:state, :string, default: "accept")

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
  end

  def get(%User{} = follower, %User{} = following) do
    __MODULE__
    |> where(follower_id: ^follower.id, following_id: ^following.id)
    |> Repo.one()
  end

  def update(follower, following, "reject"), do: unfollow(follower, following)

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

  def follow(%User{} = follower, %User{} = following, state \\ "accept") do
    %__MODULE__{}
    |> changeset(%{follower: follower, following: following, state: state})
    |> Repo.insert(on_conflict: :nothing)
  end

  def unfollow(%User{} = follower, %User{} = following) do
    case get(follower, following) do
      nil -> {:ok, nil}
      %__MODULE__{} = following_relationship -> Repo.delete(following_relationship)
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
    |> where([r], r.state == "pending")
    |> where([r], r.following_id == ^id)
    |> select([r, f], f)
    |> Repo.all()
  end

  def following?(%User{id: follower_id}, %User{id: followed_id}) do
    __MODULE__
    |> where(follower_id: ^follower_id, following_id: ^followed_id, state: "accept")
    |> Repo.exists?()
  end

  def following(%User{} = user) do
    following =
      __MODULE__
      |> join(:inner, [r], u in User, on: r.following_id == u.id)
      |> where([r], r.follower_id == ^user.id)
      |> where([r], r.state == "accept")
      |> select([r, u], u.follower_address)
      |> Repo.all()

    if not user.local or user.nickname in [nil, "internal.fetch"] do
      following
    else
      [user.follower_address | following]
    end
  end
end
