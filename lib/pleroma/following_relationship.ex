# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.FollowingRelationship do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Ecto.Changeset
  alias FlakeId.Ecto.CompatType
  alias Pleroma.FollowingRelationship.State
  alias Pleroma.Repo
  alias Pleroma.User

  schema "following_relationships" do
    field(:state, State, default: :follow_pending)

    belongs_to(:follower, User, type: CompatType)
    belongs_to(:following, User, type: CompatType)

    timestamps()
  end

  @doc "Returns underlying integer code for state atom"
  def state_int_code(state_atom), do: State.__enum_map__() |> Keyword.fetch!(state_atom)

  def accept_state_code, do: state_int_code(:follow_accept)

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

  def state_to_enum(state) when state in ["pending", "accept", "reject"] do
    String.to_existing_atom("follow_#{state}")
  end

  def state_to_enum(state) do
    raise "State is not convertible to Pleroma.FollowingRelationship.State: #{state}"
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
        with {:ok, _following_relationship} <-
               following_relationship
               |> cast(%{state: state}, [:state])
               |> validate_required([:state])
               |> Repo.update() do
          after_update(state, follower, following)
        end
    end
  end

  def follow(%User{} = follower, %User{} = following, state \\ :follow_accept) do
    with {:ok, _following_relationship} <-
           %__MODULE__{}
           |> changeset(%{follower: follower, following: following, state: state})
           |> Repo.insert(on_conflict: :nothing) do
      after_update(state, follower, following)
    end
  end

  def unfollow(%User{} = follower, %User{} = following) do
    case get(follower, following) do
      %__MODULE__{} = following_relationship ->
        with {:ok, _following_relationship} <- Repo.delete(following_relationship) do
          after_update(:unfollow, follower, following)
        end

      _ ->
        {:ok, nil}
    end
  end

  defp after_update(state, %User{} = follower, %User{} = following) do
    with {:ok, following} <- User.update_follower_count(following),
         {:ok, follower} <- User.update_following_count(follower) do
      Pleroma.Web.Streamer.stream("follow_relationship", %{
        state: state,
        following: following,
        follower: follower
      })

      {:ok, follower, following}
    end
  end

  def follower_count(%User{} = user) do
    %{followers: user, deactivated: false}
    |> User.Query.build()
    |> Repo.aggregate(:count, :id)
  end

  def followers_query(%User{} = user) do
    __MODULE__
    |> join(:inner, [r], u in User, on: r.follower_id == u.id)
    |> where([r], r.following_id == ^user.id)
    |> where([r], r.state == ^:follow_accept)
  end

  def followers_ap_ids(user, from_ap_ids \\ nil)

  def followers_ap_ids(_, []), do: []

  def followers_ap_ids(%User{} = user, from_ap_ids) do
    query =
      user
      |> followers_query()
      |> select([r, u], u.ap_id)

    query =
      if from_ap_ids do
        where(query, [r, u], u.ap_id in ^from_ap_ids)
      else
        query
      end

    Repo.all(query)
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
    |> where([r, f], f.is_active == true)
    |> select([r, f], f)
    |> Repo.all()
  end

  def following?(%User{id: follower_id}, %User{id: followed_id}) do
    __MODULE__
    |> where(follower_id: ^follower_id, following_id: ^followed_id, state: ^:follow_accept)
    |> Repo.exists?()
  end

  def following_query(%User{} = user) do
    __MODULE__
    |> join(:inner, [r], u in User, on: r.following_id == u.id)
    |> where([r], r.follower_id == ^user.id)
    |> where([r], r.state == ^:follow_accept)
  end

  def outgoing_pending_follow_requests_query(%User{} = follower) do
    __MODULE__
    |> where([r], r.follower_id == ^follower.id)
    |> where([r], r.state == ^:follow_pending)
  end

  def following(%User{} = user) do
    following =
      following_query(user)
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

  @doc """
  For a query with joined activity,
  keeps rows where activity's actor is followed by user -or- is NOT domain-blocked by user.
  """
  def keep_following_or_not_domain_blocked(query, user) do
    where(
      query,
      [_, activity],
      fragment(
        # "(actor's domain NOT in domain_blocks) OR (actor IS in followed AP IDs)"
        """
        NOT (substring(? from '.*://([^/]*)') = ANY(?)) OR
          ? = ANY(SELECT ap_id FROM users AS u INNER JOIN following_relationships AS fr
            ON u.id = fr.following_id WHERE fr.follower_id = ? AND fr.state = ?)
        """,
        activity.actor,
        ^user.domain_blocks,
        activity.actor,
        ^User.binary_id(user.id),
        ^accept_state_code()
      )
    )
  end

  defp validate_not_self_relationship(%Changeset{} = changeset) do
    changeset
    |> validate_follower_id_following_id_inequality()
    |> validate_following_id_follower_id_inequality()
  end

  defp validate_follower_id_following_id_inequality(%Changeset{} = changeset) do
    validate_change(changeset, :follower_id, fn _, follower_id ->
      if follower_id == get_field(changeset, :following_id) do
        [source_id: "can't be equal to following_id"]
      else
        []
      end
    end)
  end

  defp validate_following_id_follower_id_inequality(%Changeset{} = changeset) do
    validate_change(changeset, :following_id, fn _, following_id ->
      if following_id == get_field(changeset, :follower_id) do
        [target_id: "can't be equal to follower_id"]
      else
        []
      end
    end)
  end

  @spec following_ap_ids(User.t()) :: [String.t()]
  def following_ap_ids(%User{} = user) do
    user
    |> following_query()
    |> select([r, u], u.ap_id)
    |> Repo.all()
  end
end
