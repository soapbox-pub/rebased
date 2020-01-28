defmodule Mix.Tasks.Pleroma.EmailTest do
  use Pleroma.DataCase

  import Swoosh.TestAssertions

  alias Pleroma.Config
  alias Pleroma.Tests.ObanHelpers

  setup_all do
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)
    end)

    :ok
  end

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
  end
end
