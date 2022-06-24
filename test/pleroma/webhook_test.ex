# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.WebhookTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Repo
  alias Pleroma.Webhook

  test "creating a webhook" do
    %{id: id} = Webhook.create(%{url: "https://example.com/webhook", events: [:"report.created"]})

    assert %{url: "https://example.com/webhook"} = Webhook.get(id)
  end

  test "editing a webhook" do
    %{id: id} =
      webhook = Webhook.create(%{url: "https://example.com/webhook", events: [:"report.created"]})

    Webhook.update(webhook, %{events: [:"account.created"]})

    assert %{events: [:"account.created"]} = Webhook.get(id)
  end

  test "filter webhooks by type" do
    %{id: id1} =
      Webhook.create(%{url: "https://example.com/webhook1", events: [:"report.created"]})

    %{id: id2} =
      Webhook.create(%{
        url: "https://example.com/webhook2",
        events: [:"account.created", :"report.created"]
      })

    Webhook.create(%{url: "https://example.com/webhook3", events: [:"account.created"]})

    assert [%{id: ^id1}, %{id: ^id2}] = Webhook.get_by_type(:"report.created")
  end

  test "change webhook state" do
    %{id: id, enabled: true} =
      webhook = Webhook.create(%{url: "https://example.com/webhook", events: [:"report.created"]})

    Webhook.set_enabled(webhook, false)
    assert %{enabled: false} = Webhook.get(id)
  end

  test "rotate webhook secrets" do
    %{id: id, secret: secret} =
      webhook = Webhook.create(%{url: "https://example.com/webhook", events: [:"report.created"]})

    Webhook.rotate_secret(webhook)
    %{secret: new_secret} = Webhook.get(id)
    assert secret != new_secret
  end
end
