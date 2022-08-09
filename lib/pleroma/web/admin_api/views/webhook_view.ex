# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.WebhookView do
  use Pleroma.Web, :view

  alias Pleroma.Web.CommonAPI.Utils

  def render("index.json", %{webhooks: webhooks}) do
    render_many(webhooks, __MODULE__, "show.json")
  end

  def render("show.json", %{webhook: webhook}) do
    %{
      id: webhook.id |> to_string(),
      url: webhook.url,
      events: webhook.events,
      secret: webhook.secret,
      enabled: webhook.enabled,
      created_at: Utils.to_masto_date(webhook.inserted_at),
      updated_at: Utils.to_masto_date(webhook.updated_at)
    }
  end

  def render("event.json", %{type: type, object: object}) do
    %{
      type: type,
      created_at: Utils.to_masto_date(NaiveDateTime.utc_now()),
      object: object
    }
  end
end
