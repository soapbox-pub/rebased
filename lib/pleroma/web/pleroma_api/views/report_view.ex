# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.ReportView do
  use Pleroma.Web, :view

  alias Pleroma.HTML
  alias Pleroma.Web.AdminAPI.Report
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.StatusView

  def render("index.json", %{reports: reports, for: for_user}) do
    %{
      reports:
        reports[:items]
        |> Enum.map(&Report.extract_report_info/1)
        |> Enum.map(&render(__MODULE__, "show.json", Map.put(&1, :for, for_user))),
      total: reports[:total]
    }
  end

  def render("show.json", %{
        report: report,
        user: actor,
        account: account,
        statuses: statuses,
        for: for_user
      }) do
    created_at = Utils.to_masto_date(report.data["published"])

    content =
      unless is_nil(report.data["content"]) do
        HTML.filter_tags(report.data["content"])
      else
        nil
      end

    %{
      id: report.id,
      account: AccountView.render("show.json", %{user: account, for: for_user}),
      actor: AccountView.render("show.json", %{user: actor, for: for_user}),
      content: content,
      created_at: created_at,
      statuses:
        StatusView.render("index.json", %{
          activities: statuses,
          as: :activity,
          for: for_user
        }),
      state: report.data["state"]
    }
  end
end
