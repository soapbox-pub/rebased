# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Activity.Search do
  alias Pleroma.Activity
  alias Pleroma.Object.Fetcher
  alias Pleroma.Pagination
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Visibility

  require Pleroma.Constants

  import Ecto.Query

  def search(user, search_query, options \\ []) do
    index_type = if Pleroma.Config.get([:database, :rum_enabled]), do: :rum, else: :gin
    limit = Enum.min([Keyword.get(options, :limit), 40])
    offset = Keyword.get(options, :offset, 0)
    author = Keyword.get(options, :author)

    Activity
    |> Activity.with_preloaded_object()
    |> Activity.restrict_deactivated_users()
    |> restrict_public()
    |> query_with(index_type, search_query)
    |> maybe_restrict_local(user)
    |> maybe_restrict_author(author)
    |> Pagination.fetch_paginated(%{"offset" => offset, "limit" => limit}, :offset)
    |> maybe_fetch(user, search_query)
  end

  def maybe_restrict_author(query, %User{} = author) do
    from([a, o] in query,
      where: a.actor == ^author.ap_id
    )
  end

  def maybe_restrict_author(query, _), do: query

  defp restrict_public(q) do
    from([a, o] in q,
      where: fragment("?->>'type' = 'Create'", a.data),
      where: ^Pleroma.Constants.as_public() in a.recipients
    )
  end

  defp query_with(q, :gin, search_query) do
    from([a, o] in q,
      where:
        fragment(
          "to_tsvector('english', ?->>'content') @@ plainto_tsquery('english', ?)",
          o.data,
          ^search_query
        )
    )
  end

  defp query_with(q, :rum, search_query) do
    from([a, o] in q,
      where:
        fragment(
          "? @@ plainto_tsquery('english', ?)",
          o.fts_content,
          ^search_query
        ),
      order_by: [fragment("? <=> now()::date", o.inserted_at)]
    )
  end

  defp maybe_restrict_local(q, user) do
    limit = Pleroma.Config.get([:instance, :limit_to_local_content], :unauthenticated)

    case {limit, user} do
      {:all, _} -> restrict_local(q)
      {:unauthenticated, %User{}} -> q
      {:unauthenticated, _} -> restrict_local(q)
      {false, _} -> q
    end
  end

  defp restrict_local(q), do: where(q, local: true)

  defp maybe_fetch(activities, user, search_query) do
    with true <- Regex.match?(~r/https?:/, search_query),
         {:ok, object} <- Fetcher.fetch_object_from_id(search_query),
         %Activity{} = activity <- Activity.get_create_by_object_ap_id(object.data["id"]),
         true <- Visibility.visible_for_user?(activity, user) do
      [activity | activities]
    else
      _ -> activities
    end
  end
end
