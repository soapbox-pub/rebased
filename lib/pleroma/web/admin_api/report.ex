# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.Report do
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.User

  def extract_report_info(
        %{data: %{"actor" => actor, "object" => [account_ap_id | status_ap_ids]}} = report
      ) do
    user = User.get_cached_by_ap_id(actor)
    account = User.get_cached_by_ap_id(account_ap_id)

    statuses =
      status_ap_ids
      |> Enum.reject(&is_nil(&1))
      |> Enum.map(fn
        act when is_map(act) ->
          Activity.get_create_by_object_ap_id_with_object(act["id"]) ||
            Activity.get_by_ap_id_with_object(act["id"]) || make_fake_activity(act, user)

        act when is_binary(act) ->
          Activity.get_create_by_object_ap_id_with_object(act) ||
            Activity.get_by_ap_id_with_object(act)
      end)

    %{report: report, user: user, account: account, statuses: statuses}
  end

  defp make_fake_activity(act, user) do
    %Activity{
      id: "pleroma:fake:#{act["id"]}",
      data: %{
        "actor" => user.ap_id,
        "type" => "Create",
        "to" => [],
        "cc" => [],
        "object" => act["id"],
        "published" => act["published"],
        "id" => act["id"],
        "context" => "pleroma:fake"
      },
      recipients: [user.ap_id],
      object: %Object{
        data: %{
          "actor" => user.ap_id,
          "type" => "Note",
          "content" => act["content"],
          "published" => act["published"],
          "to" => [],
          "cc" => [],
          "id" => act["id"],
          "context" => "pleroma:fake"
        }
      }
    }
  end
end
