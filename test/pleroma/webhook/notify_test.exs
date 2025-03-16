# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Webhook.NotifyTest do
  use Pleroma.DataCase

  alias Pleroma.Webhook
  alias Pleroma.Webhook.Notify

  import Pleroma.Factory

  test "notifies have a valid signature" do
    activity = insert(:report_activity)

    %{secret: secret} =
      Webhook.create(%{url: "https://example.com/webhook", events: [:"report.created"]})

    Tesla.Mock.mock_global(fn %{url: "https://example.com/webhook", body: body, headers: headers} =
                                _ ->
      {"X-Hub-Signature", "sha256=" <> signature} =
        Enum.find(headers, fn {key, _} -> key == "X-Hub-Signature" end)

      assert signature == :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower)
      %Tesla.Env{status: 200, body: ""}
    end)

    [{:ok, task}] = Notify.trigger_webhooks(activity, :"report.created")

    ref = Process.monitor(task)

    receive do
      {:DOWN, ^ref, _, _, _} -> nil
    end
  end
end
