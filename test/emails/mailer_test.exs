# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emails.MailerTest do
  use Pleroma.DataCase
  alias Pleroma.Emails.Mailer

  import Swoosh.TestAssertions

  @email %Swoosh.Email{
    from: {"Pleroma", "noreply@example.com"},
    html_body: "Test email",
    subject: "Pleroma test email",
    to: [{"Test User", "user1@example.com"}]
  }

  clear_config([Pleroma.Emails.Mailer, :enabled])

  test "not send email when mailer is disabled" do
    Pleroma.Config.put([Pleroma.Emails.Mailer, :enabled], false)
    Mailer.deliver(@email)

    refute_email_sent(
      from: {"Pleroma", "noreply@example.com"},
      to: [{"Test User", "user1@example.com"}],
      html_body: "Test email",
      subject: "Pleroma test email"
    )
  end

  test "send email" do
    Mailer.deliver(@email)

    assert_email_sent(
      from: {"Pleroma", "noreply@example.com"},
      to: [{"Test User", "user1@example.com"}],
      html_body: "Test email",
      subject: "Pleroma test email"
    )
  end

  test "perform" do
    Mailer.perform(:deliver_async, @email, [])

    assert_email_sent(
      from: {"Pleroma", "noreply@example.com"},
      to: [{"Test User", "user1@example.com"}],
      html_body: "Test email",
      subject: "Pleroma test email"
    )
  end
end
