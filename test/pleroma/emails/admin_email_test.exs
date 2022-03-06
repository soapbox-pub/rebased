# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emails.AdminEmailTest do
  use Pleroma.DataCase, async: true
  import Pleroma.Factory

  alias Pleroma.Emails.AdminEmail
  alias Pleroma.Web.Router.Helpers

  test "build report email" do
    config = Pleroma.Config.get(:instance)
    to_user = insert(:user)
    reporter = insert(:user)
    account = insert(:user)

    res =
      AdminEmail.report(to_user, reporter, account, [%{name: "Test", id: "12"}], "Test comment")

    status_url = Helpers.o_status_url(Pleroma.Web.Endpoint, :notice, "12")
    reporter_url = reporter.ap_id
    account_url = account.ap_id

    assert res.to == [{to_user.name, to_user.email}]
    assert res.from == {config[:name], config[:notify_email]}
    assert res.subject == "#{config[:name]} Report"

    assert res.html_body ==
             "<p>Reported by: <a href=\"#{reporter_url}\">#{reporter.nickname}</a></p>\n<p>Reported Account: <a href=\"#{account_url}\">#{account.nickname}</a></p>\n<p>Comment: Test comment\n<p> Statuses:\n  <ul>\n    <li><a href=\"#{status_url}\">#{status_url}</li>\n  </ul>\n</p>\n\n<p>\n<a href=\"http://localhost:4001/pleroma/admin/#/reports/index\">View Reports in AdminFE</a>\n"
  end

  test "it works when the reporter is a remote user without email" do
    config = Pleroma.Config.get(:instance)
    to_user = insert(:user)
    reporter = insert(:user, email: nil, local: false)
    account = insert(:user)

    res =
      AdminEmail.report(to_user, reporter, account, [%{name: "Test", id: "12"}], "Test comment")

    assert res.to == [{to_user.name, to_user.email}]
    assert res.from == {config[:name], config[:notify_email]}
  end

  test "new unapproved registration email" do
    config = Pleroma.Config.get(:instance)
    to_user = insert(:user)
    account = insert(:user, registration_reason: "Plz let me in")

    res = AdminEmail.new_unapproved_registration(to_user, account)

    account_url = account.ap_id

    assert res.to == [{to_user.name, to_user.email}]
    assert res.from == {config[:name], config[:notify_email]}
    assert res.subject == "New account up for review on #{config[:name]} (@#{account.nickname})"

    assert res.html_body == """
           <p>New account for review: <a href="#{account_url}">@#{account.nickname}</a></p>
           <blockquote>Plz let me in</blockquote>
           <a href="http://localhost:4001/pleroma/admin/#/users/#{account.id}/">Visit AdminFE</a>
           """
  end
end
