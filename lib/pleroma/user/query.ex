# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.Query do
  @moduledoc """
  User query builder module. Builds query from new query or another user query.

    ## Example:
        query = Pleroma.User.Query.build(%{nickname: "nickname"})
        another_query = Pleroma.User.Query.build(query, %{email: "email@example.com"})
        Pleroma.Repo.all(query)
        Pleroma.Repo.all(another_query)

  Adding new rules:
    - *ilike criteria*
      - add field to @ilike_criteria list
      - pass non empty string
      - e.g. Pleroma.User.Query.build(%{nickname: "nickname"})
    - *equal criteria*
      - add field to @equal_criteria list
      - pass non empty string
      - e.g. Pleroma.User.Query.build(%{email: "email@example.com"})
    - *contains criteria*
      - add field to @containns_criteria list
      - pass values list
      - e.g. Pleroma.User.Query.build(%{ap_id: ["http://ap_id1", "http://ap_id2"]})
  """
  import Ecto.Query
  import Pleroma.Web.AdminAPI.Search, only: [not_empty_string: 1]

  alias Pleroma.FollowingRelationship
  alias Pleroma.User

  @type criteria ::
          %{
            query: String.t(),
            tags: [String.t()],
            name: String.t(),
            email: String.t(),
            local: boolean(),
            external: boolean(),
            active: boolean(),
            deactivated: boolean(),
            is_admin: boolean(),
            is_moderator: boolean(),
            super_users: boolean(),
            followers: User.t(),
            friends: User.t(),
            recipients_from_activity: [String.t()],
            nickname: [String.t()],
            ap_id: [String.t()],
            order_by: term(),
            select: term(),
            limit: pos_integer()
          }
          | %{}

  @ilike_criteria [:nickname, :name, :query]
  @equal_criteria [:email]
  @contains_criteria [:ap_id, :nickname]

  @spec build(criteria()) :: Query.t()
  def build(query \\ base_query(), criteria) do
    prepare_query(query, criteria)
  end

  @spec paginate(Ecto.Query.t(), pos_integer(), pos_integer()) :: Ecto.Query.t()
  def paginate(query, page, page_size) do
    from(u in query,
      limit: ^page_size,
      offset: ^((page - 1) * page_size)
    )
  end

  defp base_query do
    from(u in User)
  end

  defp prepare_query(query, criteria) do
    Enum.reduce(criteria, query, &compose_query/2)
  end

  defp compose_query({key, value}, query)
       when key in @ilike_criteria and not_empty_string(value) do
    # hack for :query key
    key = if key == :query, do: :nickname, else: key
    where(query, [u], ilike(field(u, ^key), ^"%#{value}%"))
  end

  defp compose_query({key, value}, query)
       when key in @equal_criteria and not_empty_string(value) do
    where(query, [u], ^[{key, value}])
  end

  defp compose_query({key, values}, query) when key in @contains_criteria and is_list(values) do
    where(query, [u], field(u, ^key) in ^values)
  end

  defp compose_query({:tags, tags}, query) when is_list(tags) and length(tags) > 0 do
    Enum.reduce(tags, query, &prepare_tag_criteria/2)
  end

  defp compose_query({:is_admin, _}, query) do
    where(query, [u], u.is_admin)
  end

  defp compose_query({:is_moderator, _}, query) do
    where(query, [u], u.is_moderator)
  end

  defp compose_query({:super_users, _}, query) do
    where(
      query,
      [u],
      u.is_admin or u.is_moderator
    )
  end

  defp compose_query({:local, _}, query), do: location_query(query, true)

  defp compose_query({:external, _}, query), do: location_query(query, false)

  defp compose_query({:active, _}, query) do
    User.restrict_deactivated(query)
    |> where([u], not is_nil(u.nickname))
  end

  defp compose_query({:legacy_active, _}, query) do
    query
    |> where([u], fragment("not (?->'deactivated' @> 'true')", u.info))
    |> where([u], not is_nil(u.nickname))
  end

  defp compose_query({:deactivated, false}, query) do
    User.restrict_deactivated(query)
  end

  defp compose_query({:deactivated, true}, query) do
    where(query, [u], u.deactivated == ^true)
    |> where([u], not is_nil(u.nickname))
  end

  defp compose_query({:followers, %User{id: id}}, query) do
    query
    |> where([u], u.id != ^id)
    |> join(:inner, [u], r in FollowingRelationship,
      as: :relationships,
      on: r.following_id == ^id and r.follower_id == u.id
    )
    |> where([relationships: r], r.state == "accept")
  end

  defp compose_query({:friends, %User{id: id}}, query) do
    query
    |> where([u], u.id != ^id)
    |> join(:inner, [u], r in FollowingRelationship,
      as: :relationships,
      on: r.following_id == u.id and r.follower_id == ^id
    )
    |> where([relationships: r], r.state == "accept")
  end

  defp compose_query({:recipients_from_activity, to}, query) do
    query
    |> join(:left, [u], r in FollowingRelationship,
      as: :relationships,
      on: r.follower_id == u.id
    )
    |> join(:left, [relationships: r], f in User,
      as: :following,
      on: f.id == r.following_id
    )
    |> where(
      [u, following: f, relationships: r],
      u.ap_id in ^to or (f.follower_address in ^to and r.state == "accept")
    )
    |> distinct(true)
  end

  defp compose_query({:order_by, key}, query) do
    order_by(query, [u], field(u, ^key))
  end

  defp compose_query({:select, keys}, query) do
    select(query, [u], ^keys)
  end

  defp compose_query({:limit, limit}, query) do
    limit(query, ^limit)
  end

  defp compose_query(_unsupported_param, query), do: query

  defp prepare_tag_criteria(tag, query) do
    or_where(query, [u], fragment("? = any(?)", ^tag, u.tags))
  end

  defp location_query(query, local) do
    where(query, [u], u.local == ^local)
    |> where([u], not is_nil(u.nickname))
  end
end
