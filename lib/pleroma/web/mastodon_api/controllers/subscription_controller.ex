# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.SubscriptionController do
  @moduledoc "The module represents functions to manage user subscriptions."
  use Pleroma.Web, :controller

  alias Pleroma.Web.Push
  alias Pleroma.Web.Push.Subscription

  action_fallback(:errors)

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(:restrict_push_enabled)
  plug(Pleroma.Web.Plugs.OAuthScopesPlug, %{scopes: ["push"]})

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.SubscriptionOperation

  # Creates PushSubscription
  # POST /api/v1/push/subscription
  #
  def create(%{assigns: %{user: user, token: token}, body_params: params} = conn, _) do
    with {:ok, _} <- Subscription.delete_if_exists(user, token),
         {:ok, subscription} <- Subscription.create(user, token, params) do
      render(conn, "show.json", subscription: subscription)
    end
  end

  # Gets PushSubscription
  # GET /api/v1/push/subscription
  #
  def show(%{assigns: %{user: user, token: token}} = conn, _params) do
    with {:ok, subscription} <- Subscription.get(user, token) do
      render(conn, "show.json", subscription: subscription)
    end
  end

  # Updates PushSubscription
  # PUT /api/v1/push/subscription
  #
  def update(%{assigns: %{user: user, token: token}, body_params: params} = conn, _) do
    with {:ok, subscription} <- Subscription.update(user, token, params) do
      render(conn, "show.json", subscription: subscription)
    end
  end

  # Deletes PushSubscription
  # DELETE /api/v1/push/subscription
  #
  def delete(%{assigns: %{user: user, token: token}} = conn, _params) do
    with {:ok, _response} <- Subscription.delete(user, token),
         do: json(conn, %{})
  end

  defp restrict_push_enabled(conn, _) do
    if Push.enabled() do
      conn
    else
      conn
      |> render_error(:forbidden, "Web push subscription is disabled on this Pleroma instance")
      |> halt()
    end
  end

  # fallback action
  #
  def errors(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: dgettext("errors", "Record not found")})
  end

  def errors(conn, _) do
    Pleroma.Web.MastodonAPI.FallbackController.call(conn, nil)
  end
end
