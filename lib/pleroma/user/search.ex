# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.Search do
  alias Pleroma.Repo
  alias Pleroma.User
  import Ecto.Query

  def search(query, opts \\ []) do
    resolve = Keyword.get(opts, :resolve, false)
    for_user = Keyword.get(opts, :for_user)

    # Strip the beginning @ off if there is a query
    query = String.trim_leading(query, "@")

    maybe_resolve(resolve, for_user, query)

    {:ok, results} =
      Repo.transaction(fn ->
        Ecto.Adapters.SQL.query(Repo, "select set_limit(0.25)", [])

        query
        |> search_query(for_user)
        |> Repo.all()
      end)

    results
  end

  defp maybe_resolve(true, %User{}, query) do
    User.get_or_fetch(query)
  end

  defp maybe_resolve(true, _, query) do
    unless restrict_local?(), do: User.get_or_fetch(query)
  end

  defp maybe_resolve(_, _, _), do: :noop

  defp search_query(query, for_user) do
    query
    |> union_query()
    |> distinct_query()
    |> boost_search_rank_query(for_user)
    |> subquery()
    |> order_by(desc: :search_rank)
    |> limit(20)
    |> maybe_restrict_local(for_user)
  end

  defp restrict_local? do
    Pleroma.Config.get([:instance, :limit_unauthenticated_to_local_content], true)
  end

  defp union_query(query) do
    fts_subquery = fts_search_subquery(query)
    trigram_subquery = trigram_search_subquery(query)

    from(s in trigram_subquery, union_all: ^fts_subquery)
  end

  defp distinct_query(q) do
    from(s in subquery(q), order_by: s.search_type, distinct: s.id)
  end

  # unauthenticated users can only search local activities
  defp maybe_restrict_local(q, %User{}), do: q

  defp maybe_restrict_local(q, _) do
    if restrict_local?() do
      where(q, [u], u.local == true)
    else
      q
    end
  end

  defp boost_search_rank_query(query, nil), do: query

  defp boost_search_rank_query(query, for_user) do
    friends_ids = User.get_friends_ids(for_user)
    followers_ids = User.get_followers_ids(for_user)

    from(u in subquery(query),
      select_merge: %{
        search_rank:
          fragment(
            """
             CASE WHEN (?) THEN (?) * 1.3
             WHEN (?) THEN (?) * 1.2
             WHEN (?) THEN (?) * 1.1
             ELSE (?) END
            """,
            u.id in ^friends_ids and u.id in ^followers_ids,
            u.search_rank,
            u.id in ^friends_ids,
            u.search_rank,
            u.id in ^followers_ids,
            u.search_rank,
            u.search_rank
          )
      }
    )
  end

  defp fts_search_subquery(term, query \\ User) do
    processed_query =
      term
      |> String.replace(~r/\W+/, " ")
      |> String.trim()
      |> String.split()
      |> Enum.map(&(&1 <> ":*"))
      |> Enum.join(" | ")

    from(
      u in query,
      select_merge: %{
        search_type: ^0,
        search_rank:
          fragment(
            """
            ts_rank_cd(
              setweight(to_tsvector('simple', regexp_replace(?, '\\W', ' ', 'g')), 'A') ||
              setweight(to_tsvector('simple', regexp_replace(coalesce(?, ''), '\\W', ' ', 'g')), 'B'),
              to_tsquery('simple', ?),
              32
            )
            """,
            u.nickname,
            u.name,
            ^processed_query
          )
      },
      where:
        fragment(
          """
            (setweight(to_tsvector('simple', regexp_replace(?, '\\W', ' ', 'g')), 'A') ||
            setweight(to_tsvector('simple', regexp_replace(coalesce(?, ''), '\\W', ' ', 'g')), 'B')) @@ to_tsquery('simple', ?)
          """,
          u.nickname,
          u.name,
          ^processed_query
        )
    )
    |> User.restrict_deactivated()
  end

  defp trigram_search_subquery(term) do
    from(
      u in User,
      select_merge: %{
        # ^1 gives 'Postgrex expected a binary, got 1' for some weird reason
        search_type: fragment("?", 1),
        search_rank:
          fragment(
            "similarity(?, trim(? || ' ' || coalesce(?, '')))",
            ^term,
            u.nickname,
            u.name
          )
      },
      where: fragment("trim(? || ' ' || coalesce(?, '')) % ?", u.nickname, u.name, ^term)
    )
    |> User.restrict_deactivated()
  end
end
