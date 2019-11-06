# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ReportView do
  use Pleroma.Web, :view
  alias Pleroma.HTML
  alias Pleroma.User
  alias Pleroma.Web.AdminAPI.Report
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.StatusView

  def render("index.json", %{reports: reports}) do
    %{
      reports:
        reports[:items]
        |> Enum.map(&Report.extract_report_info(&1))
        |> Enum.map(&render(__MODULE__, "show.json", &1))
        |> Enum.reverse(),
      total: reports[:total]
    }
  end

  def render("show.json", %{report: report, user: user, account: account, statuses: statuses}) do
    created_at = Utils.to_masto_date(report.data["published"])

    content =
      unless is_nil(report.data["content"]) do
        HTML.filter_tags(report.data["content"])
      else
        nil
      end

    %{
      id: report.id,
      account: merge_account_views(account),
      actor: merge_account_views(user),
      content: content,
      created_at: created_at,
      statuses: StatusView.render("index.json", %{activities: statuses, as: :activity}),
      state: report.data["state"]
    }
  end

  def render("index_grouped.json", %{groups: groups}) do
    reports =
      Enum.map(groups, fn group ->
        %{
          date: group[:date],
          account: group[:account],
          status: group[:status],
          actors: Enum.map(group[:actors], &merge_account_views/1),
          reports:
            group[:reports]
            |> Enum.map(&Report.extract_report_info(&1))
            |> Enum.map(&render(__MODULE__, "show.json", &1))
        }
      end)

    %{
      reports: reports
    }
  end

  defp merge_account_views(%User{} = user) do
    Pleroma.Web.MastodonAPI.AccountView.render("show.json", %{user: user})
    |> Map.merge(Pleroma.Web.AdminAPI.AccountView.render("show.json", %{user: user}))
  end

  defp merge_account_views(_), do: %{}
end
