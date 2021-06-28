# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Pleroma.Web.PleromaAPI.GroupController do
  use Pleroma.Web, :controller

  alias Pleroma.Group
  alias Pleroma.User
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  plug(OAuthScopesPlug, %{scopes: ["write:groups"]} when action in [:create])
  plug(OAuthScopesPlug, %{scopes: ["read:groups"]} when action in [:show])

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.GroupOperation

  def create(%{assigns: %{user: %User{} = user}, body_params: params} = conn, _) do
    params = %{
      slug: params[:slug],
      name: params[:display_name],
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
end
