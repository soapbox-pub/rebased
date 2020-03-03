# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.FilterController do
  use Pleroma.Web, :controller

  alias Pleroma.Filter
  alias Pleroma.Plugs.OAuthScopesPlug

  @oauth_read_actions [:show, :index]

  plug(OAuthScopesPlug, %{scopes: ["read:filters"]} when action in @oauth_read_actions)

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:filters"]} when action not in @oauth_read_actions
  )

  plug(Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug)

  @doc "GET /api/v1/filters"
  def index(%{assigns: %{user: user}} = conn, _) do
    filters = Filter.get_filters(user)

    render(conn, "filters.json", filters: filters)
  end

  @doc "POST /api/v1/filters"
  def create(
        %{assigns: %{user: user}} = conn,
        %{"phrase" => phrase, "context" => context} = params
      ) do
    query = %Filter{
      user_id: user.id,
      phrase: phrase,
      context: context,
      hide: Map.get(params, "irreversible", false),
      whole_word: Map.get(params, "boolean", true)
      # expires_at
    }

    {:ok, response} = Filter.create(query)

    render(conn, "filter.json", filter: response)
  end

  @doc "GET /api/v1/filters/:id"
  def show(%{assigns: %{user: user}} = conn, %{"id" => filter_id}) do
    filter = Filter.get(filter_id, user)

    render(conn, "filter.json", filter: filter)
  end

  @doc "PUT /api/v1/filters/:id"
  def update(
        %{assigns: %{user: user}} = conn,
        %{"phrase" => phrase, "context" => context, "id" => filter_id} = params
      ) do
    query = %Filter{
      user_id: user.id,
      filter_id: filter_id,
      phrase: phrase,
      context: context,
      hide: Map.get(params, "irreversible", nil),
      whole_word: Map.get(params, "boolean", true)
      # expires_at
    }

    {:ok, response} = Filter.update(query)
    render(conn, "filter.json", filter: response)
  end

  @doc "DELETE /api/v1/filters/:id"
  def delete(%{assigns: %{user: user}} = conn, %{"id" => filter_id}) do
    query = %Filter{
      user_id: user.id,
      filter_id: filter_id
    }

    {:ok, _} = Filter.delete(query)
    json(conn, %{})
  end
end
