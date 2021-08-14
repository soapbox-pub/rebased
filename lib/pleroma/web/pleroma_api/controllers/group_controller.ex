# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Pleroma.Web.PleromaAPI.GroupController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper,
    only: [try_render: 3, add_link_headers: 2, embed_relationships?: 1]

  alias Pleroma.Group
  alias Pleroma.Pagination
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.FallbackController
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:groups"]} when action in [:create, :join, :leave, :post]
  )

  plug(OAuthScopesPlug, %{scopes: ["read:groups"]} when action in [:show, :statuses, :members])
  plug(OAuthScopesPlug, %{scopes: ["read:memberships"]} when action in [:relationships])

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.GroupOperation

  def create(%{assigns: %{user: %User{} = user}, body_params: params} = conn, _) do
    params = %{
      slug: params[:slug],
      name: params[:display_name],
      description: params[:note],
      locked: params[:locked],
      privacy: params[:privacy],
      owner_id: user.id
    }

    with {:ok, %Group{} = group} <- Group.create(params) do
      render(conn, "show.json", %{group: group})
    end
  end

  def show(%{assigns: %{user: %User{}}} = conn, %{id: id}) do
    with %Group{} = group <- Group.get_by_slug_or_id(id) do
      render(conn, "show.json", %{group: group})
    end
  end

  def join(%{assigns: %{user: %User{} = user}} = conn, %{id: id}) do
    with %Group{} = group <- Group.get_by_id(id),
         {:ok, _, _, _} <- CommonAPI.join(user, group) do
      render(conn, "relationship.json", %{user: user, group: group})
    end
  end

  def leave(%{assigns: %{user: %User{} = user}} = conn, %{id: id}) do
    with %Group{} = group <- Group.get_by_id(id),
         {:ok, _, _, _} <- CommonAPI.leave(user, group) do
      render(conn, "relationship.json", %{user: user, group: group})
    end
  end

  def relationships(%{assigns: %{user: %User{} = user}} = conn, %{id: id}) do
    groups = Group.get_all_by_ids(List.wrap(id))
    render(conn, "relationships.json", user: user, groups: groups)
  end

  def statuses(%{assigns: %{user: reading_user}} = conn, %{id: id}) do
    with %Group{} = group <- Group.get_by_id(id) do
      activities = Group.Timeline.fetch_group_activities(group)

      conn
      |> add_link_headers(activities)
      |> render("statuses.json",
        activities: activities,
        for: reading_user,
        as: :activity
      )
    end
  end

  defp get_members_paginated(%Group{} = group, params) do
    group
    |> Group.get_members_query()
    |> Pagination.fetch_paginated(params)
  end

  def members(%{assigns: %{user: %User{} = user}} = conn, %{id: id} = params) do
    with %Group{} = group <- Group.get_by_id(id) do
      params = normalize_params(params)
      members = get_members_paginated(group, params)

      conn
      |> add_link_headers(members)
      |> render("accounts.json",
        for: user,
        users: members,
        as: :user,
        embed_relationships: embed_relationships?(params)
      )
    else
      nil -> FallbackController.call(conn, {:error, :not_found}) |> halt()
    end
  end

  def post(%{assigns: %{user: user}, body_params: %{status: _} = params} = conn, %{id: id}) do
    params =
      params
      |> Map.put(:in_reply_to_status_id, params[:in_reply_to_id])
      |> Map.put(:group_id, id)
      |> put_application(conn)

    with {:ok, activity} <- CommonAPI.post(user, params) do
      try_render(conn, "status.json",
        activity: activity,
        for: user,
        as: :activity,
        with_direct_conversation_id: true
      )
    else
      {:error, {:reject, message}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: message})

      {:error, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: message})
    end
  end

  def post(%{assigns: %{user: _user}, body_params: %{media_ids: _} = body_params} = conn, params) do
    body_params = Map.put(body_params, :status, "")
    post(%Plug.Conn{conn | body_params: body_params}, params)
  end

  defp put_application(params, %{assigns: %{token: %Token{user: %User{} = user} = token}} = _conn) do
    if user.disclose_client do
      %{client_name: client_name, website: website} = Repo.preload(token, :app).app
      Map.put(params, :generator, %{type: "Application", name: client_name, url: website})
    else
      Map.put(params, :generator, nil)
    end
  end

  defp put_application(params, _), do: Map.put(params, :generator, nil)

  defp normalize_params(params) do
    params
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> Enum.into(%{})
  end
end
