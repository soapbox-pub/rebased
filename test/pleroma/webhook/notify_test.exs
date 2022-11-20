# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Webhook.NotifyTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Webhook
  alias Pleroma.Webhook.Notify

  import Pleroma.Factory

  test "notifies have a valid signature" do
    activity = insert(:report_activity)

    %{secret: secret} =
      webhook = Webhook.create(%{url: "https://example.com/webhook", events: [:"report.created"]})

    Tesla.Mock.mock(fn %{url: "https://example.com/webhook", body: body, headers: headers} = _ ->
      {"X-Hub-Signature", "sha256=" <> signature} =
        Enum.find(headers, fn {key, _} -> key == "X-Hub-Signature" end)

      assert signature == :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16()
      %Tesla.Env{status: 200, body: ""}
    end)

    Notify.report_created(webhook, activity)
  end
end
