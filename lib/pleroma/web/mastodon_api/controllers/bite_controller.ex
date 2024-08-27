# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.BiteController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [assign_account_by_id: 2, json_response: 3]

  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  # alias Pleroma.Web.Plugs.RateLimiter

  plug(Pleroma.Web.ApiSpec.CastAndValidate, replace_params: false)

  plug(OAuthScopesPlug, %{scopes: ["write:bite"]} when action == :bite)

  # plug(RateLimiter, [name: :relations_actions] when action in @relationship_actions)
  # plug(RateLimiter, [name: :app_account_creation] when action == :create)

  plug(:assign_account_by_id)

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.BiteOperation

  @doc "POST /api/v1/bite"
  def bite(%{assigns: %{user: %{id: id}, account: %{id: id}}}, _params) do
    {:error, "Can not bite yourself"}
  end

  def bite(%{assigns: %{user: biting, account: bitten}} = conn, _) do
    with {:ok, _, _, _} <- CommonAPI.bite(biting, bitten) do
      json_response(conn, :ok, %{})
    else
      {:error, message} -> json_response(conn, :forbidden, %{error: message})
    end
  end
end
