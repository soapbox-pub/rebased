# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Pleroma.Web.PleromaAPI.GroupController do
  use Pleroma.Web, :controller

  alias Pleroma.Group
  alias Pleroma.User
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
    with %Group{} = group <- Group.get_by_id(id) do
      # TODO: Actually do the join
      render(conn, "relationship.json", %{user: user, group: group})
    end
  end

  def leave(%{assigns: %{user: %User{} = user}} = conn, %{id: id}) do
    with %Group{} = group <- Group.get_by_id(id) do
      # TODO: Actually do the leave
      render(conn, "relationship.json", %{user: user, group: group})
    end
  end

  def relationships(%{assigns: %{user: %User{} = user}} = conn, %{id: id}) do
    groups = Group.get_all_by_ids(List.wrap(id))
    render(conn, "relationships.json", user: user, groups: groups)
  end

  def statuses(%{assigns: %{user: %User{}}} = conn, %{id: _id}) do
    # TODO
    render(conn, "placeholder.json", %{})
  end

  def members(%{assigns: %{user: %User{}}} = conn, %{id: _id}) do
    # TODO
    render(conn, "placeholder.json", %{})
  end

  def post(%{assigns: %{user: %User{}}} = conn, %{id: _id}) do
    # TODO
    render(conn, "placeholder.json", %{})
  end
end
