# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.SubscriptionController do
  @moduledoc "The module represents functions to manage user subscriptions."
  use Pleroma.Web, :controller

  alias Pleroma.Web.MastodonAPI.PushSubscriptionView, as: View
  alias Pleroma.Web.Push
  alias Pleroma.Web.Push.Subscription

  action_fallback(:errors)

  plug(Pleroma.Plugs.OAuthScopesPlug, %{scopes: ["push"]})

  plug(Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug)

  # Creates PushSubscription
  # POST /api/v1/push/subscription
  #
  def create(%{assigns: %{user: user, token: token}} = conn, params) do
    with true <- Push.enabled(),
         {:ok, _} <- Subscription.delete_if_exists(user, token),
         {:ok, subscription} <- Subscription.create(user, token, params) do
      view = View.render("push_subscription.json", subscription: subscription)
      json(conn, view)
    end
  end

  # Gets PushSubscription
  # GET /api/v1/push/subscription
  #
  def get(%{assigns: %{user: user, token: token}} = conn, _params) do
    with true <- Push.enabled(),
         {:ok, subscription} <- Subscription.get(user, token) do
      view = View.render("push_subscription.json", subscription: subscription)
      json(conn, view)
    end
  end

  # Updates PushSubscription
  # PUT /api/v1/push/subscription
  #
  def update(%{assigns: %{user: user, token: token}} = conn, params) do
    with true <- Push.enabled(),
         {:ok, subscription} <- Subscription.update(user, token, params) do
      view = View.render("push_subscription.json", subscription: subscription)
      json(conn, view)
    end
  end

  # Deletes PushSubscription
  # DELETE /api/v1/push/subscription
  #
  def delete(%{assigns: %{user: user, token: token}} = conn, _params) do
    with true <- Push.enabled(),
         {:ok, _response} <- Subscription.delete(user, token),
         do: json(conn, %{})
  end

  # fallback action
  #
  def errors(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(dgettext("errors", "Not found"))
  end

  def errors(conn, _) do
    Pleroma.Web.MastodonAPI.FallbackController.call(conn, nil)
  end
end
