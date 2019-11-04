# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.Report do
  alias Pleroma.Activity
  alias Pleroma.User

  def extract_report_info(
        %{data: %{"actor" => actor, "object" => [account_ap_id | status_ap_ids]}} = report
      ) do
    user = User.get_cached_by_ap_id(actor)
    account = User.get_cached_by_ap_id(account_ap_id)

    statuses =
      Enum.map(status_ap_ids, fn
        act when is_map(act) -> Activity.get_by_ap_id_with_object(act["id"])
        act when is_binary(act) -> Activity.get_by_ap_id_with_object(act)
      end)

    %{report: report, user: user, account: account, statuses: statuses}
  end
end
