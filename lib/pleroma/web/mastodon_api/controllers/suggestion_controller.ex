# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.SuggestionController do
  use Pleroma.Web, :controller
  import Ecto.Query
  alias Pleroma.FollowingRelationship
  alias Pleroma.User
  alias Pleroma.UserRelationship

  require Logger

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(Pleroma.Web.Plugs.OAuthScopesPlug, %{scopes: ["read"]} when action in [:index, :index2])
  plug(Pleroma.Web.Plugs.OAuthScopesPlug, %{scopes: ["write"]} when action in [:dismiss])

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def index_operation do
    %OpenApiSpex.Operation{
      tags: ["Suggestions"],
      summary: "Follow suggestions (Not implemented)",
      operationId: "SuggestionController.index",
      responses: %{
        200 => Pleroma.Web.ApiSpec.Helpers.empty_array_response()
      }
    }
  end

  def index2_operation do
    %OpenApiSpex.Operation{
      tags: ["Suggestions"],
      summary: "Follow suggestions",
      operationId: "SuggestionController.index2",
      responses: %{
        200 => Pleroma.Web.ApiSpec.Helpers.empty_array_response()
      }
    }
  end

  def dismiss_operation do
    %OpenApiSpex.Operation{
      tags: ["Suggestions"],
      summary: "Remove a suggestion",
      operationId: "SuggestionController.dismiss",
      parameters: [
        OpenApiSpex.Operation.parameter(
          :account_id,
          :path,
          %OpenApiSpex.Schema{type: :string},
          "Account to dismiss",
          required: true
        )
      ],
      responses: %{
        200 => Pleroma.Web.ApiSpec.Helpers.empty_object_response()
      }
    }
  end

  @doc "GET /api/v1/suggestions"
  def index(conn, params),
    do: Pleroma.Web.MastodonAPI.MastodonAPIController.empty_array(conn, params)

  @doc "GET /api/v2/suggestions"
  def index2(%{assigns: %{user: user}} = conn, params) do
    limit = Map.get(params, :limit, 40) |> min(80)

    users =
      %{is_suggested: true, invisible: false, limit: limit}
      |> User.Query.build()
      |> exclude_user(user)
      |> exclude_relationships(user, [:block, :mute, :suggestion_dismiss])
      |> exclude_following(user)
      |> Pleroma.Repo.all()

    render(conn, "index.json", %{
      users: users,
      source: :staff,
      for: user,
      skip_visibility_check: true
    })
  end

  defp exclude_user(query, %User{id: user_id}) do
    where(query, [u], u.id != ^user_id)
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

  defp exclude_following(query, %User{id: user_id}) do
    query
    |> join(:left, [u], r in FollowingRelationship,
      as: :following_relationships,
      on: r.following_id == u.id and r.follower_id == ^user_id and r.state == :follow_accept
    )
    |> where([following_relationships: r], is_nil(r.following_id))
  end

  @doc "DELETE /api/v1/suggestions/:account_id"
  def dismiss(%{assigns: %{user: source}} = conn, %{account_id: user_id}) do
    with %User{} = target <- User.get_cached_by_id(user_id),
         {:ok, _} <- UserRelationship.create(:suggestion_dismiss, source, target) do
      json(conn, %{})
    end
  end
end
