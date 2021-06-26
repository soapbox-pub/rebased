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

  def create(%{assigns: %{user: %User{} = user}} = conn, params) do
    params = %{
      slug: params["slug"],
      name: params["display_name"],
      locked: params["locked"] in ["on", true],
      privacy: params["privacy"] || "public",
      owner_id: user.id
    }

    with {:ok, %Group{} = group} <- Group.create(params) do
      render(conn, "show.json", %{group: group})
    end
  end
end
