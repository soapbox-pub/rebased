# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.List do
  use Ecto.Schema

  import Ecto.Query
  import Ecto.Changeset

  alias Pleroma.Activity
  alias Pleroma.Repo
  alias Pleroma.User

  @ap_id_regex ~r/^\/users\/(?<nickname>\w+)\/lists\/(?<list_id>\d+)/

  schema "lists" do
    belongs_to(:user, User, type: Pleroma.FlakeId)
    field(:title, :string)
    field(:following, {:array, :string}, default: [])

    timestamps()
  end

  def title_changeset(list, attrs \\ %{}) do
    list
    |> cast(attrs, [:title])
    |> validate_required([:title])
  end

  def follow_changeset(list, attrs \\ %{}) do
    list
    |> cast(attrs, [:following])
    |> validate_required([:following])
  end

  def ap_id(%User{nickname: nickname}, list_id) do
    Pleroma.Web.Endpoint.url() <> "/users/#{nickname}/lists/#{list_id}"
  end

  def ap_id({nickname, list_id}), do: ap_id(%User{nickname: nickname}, list_id)

  def for_user(user, _opts) do
    query =
      from(
        l in Pleroma.List,
        where: l.user_id == ^user.id,
        order_by: [desc: l.id],
        limit: 50
      )

    Repo.all(query)
  end

  def get(id, %{id: user_id} = _user) do
    query =
      from(
        l in Pleroma.List,
        where: l.id == ^id,
        where: l.user_id == ^user_id
      )

    Repo.one(query)
  end

  def get_by_ap_id(ap_id) do
    host = Pleroma.Web.Endpoint.host()

    with %{host: ^host, path: path} <- URI.parse(ap_id),
         %{"list_id" => list_id, "nickname" => nickname} <-
           Regex.named_captures(@ap_id_regex, path),
         %User{} = user <- User.get_cached_by_nickname(nickname) do
      get(list_id, user)
    else
      _ -> nil
    end
  end

  def get_following(%Pleroma.List{following: following} = _list) do
    q =
      from(
        u in User,
        where: u.follower_address in ^following
      )

    {:ok, Repo.all(q)}
  end

  # Get lists the activity should be streamed to.
  def get_lists_from_activity(%Activity{actor: ap_id}) do
    actor = User.get_cached_by_ap_id(ap_id)

    query =
      from(
        l in Pleroma.List,
        where: fragment("? && ?", l.following, ^[actor.follower_address])
      )

    Repo.all(query)
  end

  # Get lists to which the account belongs.
  def get_lists_account_belongs(%User{} = owner, account_id) do
    user = User.get_cached_by_id(account_id)

    query =
      from(
        l in Pleroma.List,
        where:
          l.user_id == ^owner.id and
            fragment(
              "? = ANY(?)",
              ^user.follower_address,
              l.following
            )
      )

    Repo.all(query)
  end

  def rename(%Pleroma.List{} = list, title) do
    list
    |> title_changeset(%{title: title})
    |> Repo.update()
  end

  def create(title, %User{} = creator) do
    list = %Pleroma.List{user_id: creator.id, title: title}
    Repo.insert(list)
  end

  def follow(%Pleroma.List{following: following} = list, %User{} = followed) do
    update_follows(list, %{following: Enum.uniq([followed.follower_address | following])})
  end

  def unfollow(%Pleroma.List{following: following} = list, %User{} = unfollowed) do
    update_follows(list, %{following: List.delete(following, unfollowed.follower_address)})
  end

  def delete(%Pleroma.List{} = list) do
    Repo.delete(list)
  end

  def update_follows(%Pleroma.List{} = list, attrs) do
    list
    |> follow_changeset(attrs)
    |> Repo.update()
  end

  def memberships(%User{follower_address: follower_address}) do
    Pleroma.List
    |> where([l], ^follower_address in l.following)
    |> join(:inner, [l], u in User, on: l.user_id == u.id)
    |> select([l, u], {u.nickname, l.id})
    |> Repo.all()
    |> Enum.map(&ap_id/1)
  end

  def memberships(_), do: []
end
