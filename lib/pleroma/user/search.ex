# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.Search do
  alias Pleroma.EctoType.ActivityPub.ObjectValidators.Uri, as: UriType
  alias Pleroma.Pagination
  alias Pleroma.User

  import Ecto.Query

  @limit 20

  def search(query_string, opts \\ []) do
    resolve = Keyword.get(opts, :resolve, false)
    following = Keyword.get(opts, :following, false)
    result_limit = Keyword.get(opts, :limit, @limit)
    offset = Keyword.get(opts, :offset, 0)

    for_user = Keyword.get(opts, :for_user)

    query_string = format_query(query_string)

    # If this returns anything, it should bounce to the top
    maybe_resolved = maybe_resolve(resolve, for_user, query_string)

    top_user_ids =
      []
      |> maybe_add_resolved(maybe_resolved)
      |> maybe_add_ap_id_match(query_string)
      |> maybe_add_uri_match(query_string)

    results =
      query_string
      |> search_query(for_user, following, top_user_ids)
      |> Pagination.fetch_paginated(%{"offset" => offset, "limit" => result_limit}, :offset)

    results
  end

  defp maybe_add_resolved(list, {:ok, %User{} = user}) do
    [user.id | list]
  end

  defp maybe_add_resolved(list, _), do: list

  defp maybe_add_ap_id_match(list, query) do
    if user = User.get_cached_by_ap_id(query) do
      [user.id | list]
    else
      list
    end
  end

  defp maybe_add_uri_match(list, query) do
    with {:ok, query} <- UriType.cast(query),
         q = from(u in User, where: u.uri == ^query, select: u.id),
         users = Pleroma.Repo.all(q) do
      users ++ list
    else
      _ -> list
    end
  end

  defp format_query(query_string) do
    # Strip the beginning @ off if there is a query
    query_string = String.trim_leading(query_string, "@")

    with [name, domain] <- String.split(query_string, "@") do
      encoded_domain =
        domain
        |> String.replace(~r/[!-\-|@|[-`|{-~|\/|:|\s]+/, "")
        |> String.to_charlist()
        |> :idna.encode()
        |> to_string()

      name <> "@" <> encoded_domain
    else
      _ -> query_string
    end
  end

  defp search_query(query_string, for_user, following, top_user_ids) do
    for_user
    |> base_query(following)
    |> filter_blocked_user(for_user)
    |> filter_invisible_users()
    |> filter_internal_users()
    |> filter_blocked_domains(for_user)
    |> fts_search(query_string)
    |> select_top_users(top_user_ids)
    |> trigram_rank(query_string)
    |> boost_search_rank(for_user, top_user_ids)
    |> subquery()
    |> order_by(desc: :search_rank)
    |> maybe_restrict_local(for_user)
  end

  defp select_top_users(query, top_user_ids) do
    from(u in query,
      or_where: u.id in ^top_user_ids
    )
  end

  defp fts_search(query, query_string) do
    query_string = to_tsquery(query_string)

    from(
      u in query,
      where:
        fragment(
          # The fragment must _exactly_ match `users_fts_index`, otherwise the index won't work
          """
          (
            setweight(to_tsvector('simple', regexp_replace(?, '\\W', ' ', 'g')), 'A') ||
            setweight(to_tsvector('simple', regexp_replace(coalesce(?, ''), '\\W', ' ', 'g')), 'B')
          ) @@ to_tsquery('simple', ?)
          """,
          u.nickname,
          u.name,
          ^query_string
        )
    )
  end

  defp to_tsquery(query_string) do
    String.trim_trailing(query_string, "@" <> local_domain())
    |> String.replace(~r/[!-\/|@|[-`|{-~|:-?]+/, " ")
    |> String.trim()
    |> String.split()
    |> Enum.map(&(&1 <> ":*"))
    |> Enum.join(" | ")
  end

  # Considers nickname match, localized nickname match, name match; preferences nickname match
  defp trigram_rank(query, query_string) do
    from(
      u in query,
      select_merge: %{
        search_rank:
          fragment(
            """
            similarity(?, ?) +
            similarity(?, regexp_replace(?, '@.+', '')) +
            similarity(?, trim(coalesce(?, '')))
            """,
            ^query_string,
            u.nickname,
            ^query_string,
            u.nickname,
            ^query_string,
            u.name
          )
      }
    )
  end

  defp base_query(%User{} = user, true), do: User.get_friends_query(user)
  defp base_query(_user, _following), do: User

  defp filter_invisible_users(query) do
    from(q in query, where: q.invisible == false)
  end

  defp filter_internal_users(query) do
    from(q in query, where: q.actor_type != "Application")
  end

  defp filter_blocked_user(query, %User{} = blocker) do
    query
    |> join(:left, [u], b in Pleroma.UserRelationship,
      as: :blocks,
      on: b.relationship_type == ^:block and b.source_id == ^blocker.id and u.id == b.target_id
    )
    |> where([blocks: b], is_nil(b.target_id))
  end

  defp filter_blocked_user(query, _), do: query

  defp filter_blocked_domains(query, %User{domain_blocks: domain_blocks})
       when length(domain_blocks) > 0 do
    domains = Enum.join(domain_blocks, ",")

    from(
      q in query,
      where: fragment("substring(ap_id from '.*://([^/]*)') NOT IN (?)", ^domains)
    )
  end

  defp filter_blocked_domains(query, _), do: query

  defp maybe_resolve(true, user, query) do
    case {limit(), user} do
      {:all, _} -> :noop
      {:unauthenticated, %User{}} -> User.get_or_fetch(query)
      {:unauthenticated, _} -> :noop
      {false, _} -> User.get_or_fetch(query)
    end
  end

  defp maybe_resolve(_, _, _), do: :noop

  defp maybe_restrict_local(q, user) do
    case {limit(), user} do
      {:all, _} -> restrict_local(q)
      {:unauthenticated, %User{}} -> q
      {:unauthenticated, _} -> restrict_local(q)
      {false, _} -> q
    end
  end

  defp limit, do: Pleroma.Config.get([:instance, :limit_to_local_content], :unauthenticated)

  defp restrict_local(q), do: where(q, [u], u.local == true)

  defp local_domain, do: Pleroma.Config.get([Pleroma.Web.Endpoint, :url, :host])

  defp boost_search_rank(query, %User{} = for_user, top_user_ids) do
    friends_ids = User.get_friends_ids(for_user)
    followers_ids = User.get_followers_ids(for_user)

    from(u in subquery(query),
      select_merge: %{
        search_rank:
          fragment(
            """
             CASE WHEN (?) THEN (?) * 1.5
             WHEN (?) THEN (?) * 1.3
             WHEN (?) THEN (?) * 1.1
             WHEN (?) THEN 9001
             ELSE (?) END
            """,
            u.id in ^friends_ids and u.id in ^followers_ids,
            u.search_rank,
            u.id in ^friends_ids,
            u.search_rank,
            u.id in ^followers_ids,
            u.search_rank,
            u.id in ^top_user_ids,
            u.search_rank
          )
      }
    )
  end

  defp boost_search_rank(query, _for_user, top_user_ids) do
    from(u in subquery(query),
      select_merge: %{
        search_rank:
          fragment(
            """
             CASE WHEN (?) THEN 9001
             ELSE (?) END
            """,
            u.id in ^top_user_ids,
            u.search_rank
          )
      }
    )
  end
end
