# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.EmailTest do
  use Pleroma.DataCase

  import Swoosh.TestAssertions

  alias Pleroma.Config
  alias Pleroma.Tests.ObanHelpers

  import Pleroma.Factory

  setup_all do
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)
    end)

    :ok
  end

  setup do: clear_config([Pleroma.Emails.Mailer, :enabled], true)
  setup do: clear_config([:instance, :account_activation_required], true)

  describe "pleroma.email test" do
    test "Sends test email with no given address" do
      mail_to = Config.get([:instance, :email])

      :ok = Mix.Tasks.Pleroma.Email.run(["test"])

      ObanHelpers.perform_all()

      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "Test email has been sent"

      assert_email_sent(
        to: mail_to,
        html_body: ~r/a test email was requested./i
      )
    end

    test "Sends test email with given address" do
      mail_to = "hewwo@example.com"

      :ok = Mix.Tasks.Pleroma.Email.run(["test", "--to", mail_to])

      ObanHelpers.perform_all()

      assert_receive {:mix_shell, :info, [message]}
      assert message =~ "Test email has been sent"

      assert_email_sent(
        to: mail_to,
        html_body: ~r/a test email was requested./i
      )
    end

    test "Sends confirmation emails" do
      local_user1 =
        insert(:user, %{
          is_confirmed: false,
          confirmation_token: "mytoken",
          is_active: true,
          email: "local1@pleroma.com",
          local: true
        })

      local_user2 =
        insert(:user, %{
          is_confirmed: false,
          confirmation_token: "mytoken",
          is_active: true,
          email: "local2@pleroma.com",
          local: true
        })

      :ok = Mix.Tasks.Pleroma.Email.run(["resend_confirmation_emails"])

      ObanHelpers.perform_all()

      assert_email_sent(to: {local_user1.name, local_user1.email})
      assert_email_sent(to: {local_user2.name, local_user2.email})
    end

    test "Does not send confirmation email to inappropriate users" do
      # confirmed user
      insert(:user, %{
        is_confirmed: true,
        confirmation_token: "mytoken",
        is_active: true,
        email: "confirmed@pleroma.com",
        local: true
      })

      # remote user
      insert(:user, %{
        is_active: true,
        email: "remote@not-pleroma.com",
        local: false
      })

      # deactivated user =
      insert(:user, %{
        is_active: false,
        email: "deactivated@pleroma.com",
        local: false
      })

      # invisible user
      insert(:user, %{
        is_active: true,
        email: "invisible@pleroma.com",
        local: true,
        invisible: true
      })

      :ok = Mix.Tasks.Pleroma.Email.run(["resend_confirmation_emails"])

      ObanHelpers.perform_all()

      refute_email_sent()
    end
  end
end
