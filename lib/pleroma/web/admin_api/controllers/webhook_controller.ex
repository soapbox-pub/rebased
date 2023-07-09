# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.WebhookController do
  use Pleroma.Web, :controller

  alias Pleroma.Repo
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Pleroma.Webhook

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    OAuthScopesPlug,
    %{scopes: ["admin:write"]}
    when action in [:update, :create, :delete, :enable, :disable, :rotate_secret]
  )

  plug(OAuthScopesPlug, %{scopes: ["admin:read"]} when action in [:index, :show])

  action_fallback(Pleroma.Web.AdminAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.Admin.WebhookOperation

  def index(conn, _) do
    webhooks =
      Webhook
      |> Repo.all()

    render(conn, "index.json", webhooks: webhooks)
  end

  def show(conn, %{id: id}) do
    with %Webhook{} = webhook <- Webhook.get(id) do
      render(conn, "show.json", webhook: webhook)
    else
      nil -> {:error, :not_found}
    end
  end

  def create(%{body_params: params} = conn, _) do
    with webhook <- Webhook.create(params) do
      render(conn, "show.json", webhook: webhook)
    end
  end

  def update(%{body_params: params} = conn, %{id: id}) do
    with %Webhook{internal: false} = webhook <- Webhook.get(id),
         webhook <- Webhook.update(webhook, params) do
      render(conn, "show.json", webhook: webhook)
    else
      %Webhook{internal: true} -> {:error, :forbidden}
    end
  end

  def delete(conn, %{id: id}) do
    with %Webhook{internal: false} = webhook <- Webhook.get(id),
         {:ok, webhook} <- Webhook.delete(webhook) do
      render(conn, "show.json", webhook: webhook)
    else
      %Webhook{internal: true} -> {:error, :forbidden}
    end
  end

  def enable(conn, %{id: id}) do
    with %Webhook{internal: false} = webhook <- Webhook.get(id),
         {:ok, webhook} <- Webhook.set_enabled(webhook, true) do
      render(conn, "show.json", webhook: webhook)
    else
      %Webhook{internal: true} -> {:error, :forbidden}
      nil -> {:error, :not_found}
    end
  end

  def disable(conn, %{id: id}) do
    with %Webhook{internal: false} = webhook <- Webhook.get(id),
         {:ok, webhook} <- Webhook.set_enabled(webhook, false) do
      render(conn, "show.json", webhook: webhook)
    else
      %Webhook{internal: true} -> {:error, :forbidden}
      nil -> {:error, :not_found}
    end
  end

  def rotate_secret(conn, %{id: id}) do
    with %Webhook{internal: false} = webhook <- Webhook.get(id),
         {:ok, webhook} <- Webhook.rotate_secret(webhook) do
      render(conn, "show.json", webhook: webhook)
    else
      %Webhook{internal: true} -> {:error, :forbidden}
      nil -> {:error, :not_found}
    end
  end
end
