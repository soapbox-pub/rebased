# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.FilterController do
  use Pleroma.Web, :controller

  alias Pleroma.Filter
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  @oauth_read_actions [:show, :index]

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(OAuthScopesPlug, %{scopes: ["read:filters"]} when action in @oauth_read_actions)

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:filters"]} when action not in @oauth_read_actions
  )

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.FilterOperation

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  @doc "GET /api/v1/filters"
  def index(%{assigns: %{user: user}} = conn, _) do
    filters = Filter.get_filters(user)

    render(conn, "index.json", filters: filters)
  end

  @doc "POST /api/v1/filters"
  def create(%{assigns: %{user: user}, body_params: params} = conn, _) do
    with {:ok, response} <-
           params
           |> Map.put(:user_id, user.id)
           |> Map.put(:hide, params[:irreversible])
           |> Map.delete(:irreversible)
           |> Filter.create() do
      render(conn, "show.json", filter: response)
    end
  end

  @doc "GET /api/v1/filters/:id"
  def show(%{assigns: %{user: user}} = conn, %{id: filter_id}) do
    with %Filter{} = filter <- Filter.get(filter_id, user) do
      render(conn, "show.json", filter: filter)
    else
      nil -> {:error, :not_found}
    end
  end

  @doc "PUT /api/v1/filters/:id"
  def update(
        %{assigns: %{user: user}, body_params: params} = conn,
        %{id: filter_id}
      ) do
    params =
      if is_boolean(params[:irreversible]) do
        params
        |> Map.put(:hide, params[:irreversible])
        |> Map.delete(:irreversible)
      else
        params
      end

    with %Filter{} = filter <- Filter.get(filter_id, user),
         {:ok, %Filter{} = filter} <- Filter.update(filter, params) do
      render(conn, "show.json", filter: filter)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  @doc "DELETE /api/v1/filters/:id"
  def delete(%{assigns: %{user: user}} = conn, %{id: filter_id}) do
    with %Filter{} = filter <- Filter.get(filter_id, user),
         {:ok, _} <- Filter.delete(filter) do
      json(conn, %{})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end
end
