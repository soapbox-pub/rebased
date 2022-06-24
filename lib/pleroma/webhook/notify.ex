# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Webhook.Notify do
  alias Phoenix.View
  alias Pleroma.Activity
  alias Pleroma.User
  alias Pleroma.Web.AdminAPI.Report
  alias Pleroma.Webhook

  def trigger_webhooks(%Activity{} = activity, :"report.created" = type) do
    webhooks = Webhook.get_by_type(type)

    Enum.each(webhooks, fn webhook ->
      ConcurrentLimiter.limit(Webhook.Notify, fn ->
        Task.start(fn -> report_created(webhook, activity) end)
      end)
    end)
  end

  def trigger_webhooks(%User{} = user, :"account.created" = type) do
    webhooks = Webhook.get_by_type(type)

    Enum.each(webhooks, fn webhook ->
      ConcurrentLimiter.limit(Webhook.Notify, fn ->
        Task.start(fn -> account_created(webhook, user) end)
      end)
    end)
  end

  def report_created(%Webhook{} = webhook, %Activity{} = report) do
    object =
      View.render(
        Pleroma.Web.MastodonAPI.Admin.ReportView,
        "show.json",
        Report.extract_report_info(report)
      )

    deliver(webhook, object, :"report.created")
  end

  def account_created(%Webhook{} = webhook, %User{} = user) do
    object =
      View.render(
        Pleroma.Web.MastodonAPI.Admin.AccountView,
        "show.json",
        user: user
      )

    deliver(webhook, object, :"account.created")
  end

  defp deliver(%Webhook{url: url, secret: secret}, object, type) do
    body =
      View.render_to_string(Pleroma.Web.AdminAPI.WebhookView, "event.json",
        type: type,
        object: object
      )

    headers = [
      {"Content-Type", "application/json"},
      {"X-Hub-Signature", "sha256=#{signature(body, secret)}"}
    ]

    Pleroma.HTTP.post(url, body, headers)
  end

  defp signature(body, secret) do
    :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16()
  end
end
