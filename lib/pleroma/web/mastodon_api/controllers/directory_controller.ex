# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.DirectoryController do
  use Pleroma.Web, :controller

  import Ecto.Query
  alias Pleroma.Pagination
  alias Pleroma.User
  alias Pleroma.UserRelationship
  alias Pleroma.Web.MastodonAPI.AccountView

  require Logger

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(:skip_auth when action == "index")

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.DirectoryOperation

  @doc "GET /api/v1/directory"
  def index(%{assigns: %{user: user}} = conn, params) do
    with true <- Pleroma.Config.get([:instance, :profile_directory]) do
      limit = Map.get(params, :limit, 20) |> min(80)

      users =
        User.Query.build(%{is_discoverable: true, invisible: false, limit: limit})
        |> order_by_creation_date(params)
        |> exclude_remote(params)
        |> exclude_user(user)
        |> exclude_relationships(user, [:block, :mute])
        |> Pagination.fetch_paginated(params, :offset)

      conn
      |> put_view(AccountView)
      |> render("index.json", for: user, users: users, as: :user)
    else
      _ -> json(conn, [])
    end
  end

  defp order_by_creation_date(query, %{order: "new"}) do
    query
  end

  defp order_by_creation_date(query, _params) do
    query
    |> order_by([u], desc_nulls_last: u.last_status_at)
  end

  defp exclude_remote(query, %{local: true}) do
    where(query, [u], u.local == true)
  end

  defp exclude_remote(query, _params) do
    query
  end

  defp exclude_user(query, %User{id: user_id}) do
    where(query, [u], u.id != ^user_id)
  end

  defp exclude_user(query, _user) do
    query
  end

  defp exclude_relationships(query, %User{id: user_id}, relationship_types) do
    query
    |> join(:left, [u], r in UserRelationship,
      as: :user_relationships,
      on:
        r.target_id == u.id and r.source_id == ^user_id and
          r.relationship_type in ^relationship_types
    )
    |> where([user_relationships: r], is_nil(r.target_id))
  end

  defp exclude_relationships(query, _user, _relationship_types) do
    query
  end
end
