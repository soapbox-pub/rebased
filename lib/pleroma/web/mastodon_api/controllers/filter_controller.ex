# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.FilterController do
  use Pleroma.Web, :controller

  alias Pleroma.Filter
  alias Pleroma.Plugs.OAuthScopesPlug

  @oauth_read_actions [:show, :index]

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(OAuthScopesPlug, %{scopes: ["read:filters"]} when action in @oauth_read_actions)

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:filters"]} when action not in @oauth_read_actions
  )
  
  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.FilterOperation

  @doc "GET /api/v1/filters"
  def index(%{assigns: %{user: user}} = conn, _) do
    filters = Filter.get_filters(user)

    render(conn, "index.json", filters: filters)
  end

  @doc "POST /api/v1/filters"
  def create(%{assigns: %{user: user}, body_params: params} = conn, _) do
    query = %Filter{
      user_id: user.id,
      phrase: params.phrase,
      context: params.context,
      hide: params.irreversible,
      whole_word: params.whole_word
      # TODO: support `expires_in` parameter (as in Mastodon API)
    }

    {:ok, response} = Filter.create(query)

    render(conn, "show.json", filter: response)
  end

  @doc "GET /api/v1/filters/:id"
  def show(%{assigns: %{user: user}} = conn, %{id: filter_id}) do
    filter = Filter.get(filter_id, user)

    render(conn, "show.json", filter: filter)
  end

  @doc "PUT /api/v1/filters/:id"
  def update(
        %{assigns: %{user: user}, body_params: params} = conn,
        %{id: filter_id}
      ) do
    params =
      params
      |> Map.delete(:irreversible)
      |> Map.put(:hide, params[:irreversible])
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    # TODO: support `expires_in` parameter (as in Mastodon API)

    with %Filter{} = filter <- Filter.get(filter_id, user),
         {:ok, %Filter{} = filter} <- Filter.update(filter, params) do
      render(conn, "show.json", filter: filter)
    end
  end

  @doc "DELETE /api/v1/filters/:id"
  def delete(%{assigns: %{user: user}} = conn, %{id: filter_id}) do
    query = %Filter{
      user_id: user.id,
      filter_id: filter_id
    }

    {:ok, _} = Filter.delete(query)
    json(conn, %{})
  end
end
