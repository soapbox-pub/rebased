# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ReportView do
  use Pleroma.Web, :view
  alias Pleroma.Activity
  alias Pleroma.HTML
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.StatusView

  def render("index.json", %{reports: reports}) do
    %{
      reports: render_many(reports, __MODULE__, "show.json", as: :report)
    }
  end

  def render("show.json", %{report: report}) do
    user = User.get_cached_by_ap_id(report.data["actor"])
    created_at = Utils.to_masto_date(report.data["published"])

    [account_ap_id | status_ap_ids] = report.data["object"]
    account = User.get_cached_by_ap_id(account_ap_id)

    content =
      unless is_nil(report.data["content"]) do
        HTML.filter_tags(report.data["content"])
      else
        nil
      end

    statuses =
      Enum.map(status_ap_ids, fn ap_id ->
        Activity.get_by_ap_id_with_object(ap_id)
      end)

    %{
      id: report.id,
      account: AccountView.render("account.json", %{user: account}),
      actor: AccountView.render("account.json", %{user: user}),
      content: content,
      created_at: created_at,
      statuses: StatusView.render("index.json", %{activities: statuses, as: :activity}),
      state: report.data["state"]
    }
  end
end
