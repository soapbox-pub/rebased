# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emails.AdminEmailTest do
  use Pleroma.DataCase
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
    reporter_url = Helpers.o_status_url(Pleroma.Web.Endpoint, :feed_redirect, reporter.nickname)
    account_url = Helpers.o_status_url(Pleroma.Web.Endpoint, :feed_redirect, account.nickname)

    assert res.to == [{to_user.name, to_user.email}]
    assert res.from == {config[:name], config[:notify_email]}
    assert res.reply_to == {reporter.name, reporter.email}
    assert res.subject == "#{config[:name]} Report"

    assert res.html_body ==
             "<p>Reported by: <a href=\"#{reporter_url}\">#{reporter.nickname}</a></p>\n<p>Reported Account: <a href=\"#{
               account_url
             }\">#{account.nickname}</a></p>\n<p>Comment: Test comment\n<p> Statuses:\n  <ul>\n    <li><a href=\"#{
               status_url
             }\">#{status_url}</li>\n  </ul>\n</p>\n\n"
  end
end
