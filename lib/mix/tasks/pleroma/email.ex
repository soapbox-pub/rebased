# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Email do
  use Mix.Task
  import Mix.Pleroma

  @shortdoc "Email administrative tasks"
  @moduledoc File.read!("docs/administration/CLI_tasks/email.md")

  def run(["test" | args]) do
    start_pleroma()

    {options, [], []} =
      OptionParser.parse(
        args,
        strict: [
          to: :string
        ]
      )

    email = Pleroma.Emails.AdminEmail.test_email(options[:to])
    {:ok, _} = Pleroma.Emails.Mailer.deliver(email)

    shell_info("Test email has been sent to #{inspect(email.to)} from #{inspect(email.from)}")
  end

  def run(["resend_confirmation_emails"]) do
    start_pleroma()

    shell_info("Sending emails to all unconfirmed users")

    Pleroma.User.Query.build(%{
      local: true,
      is_active: true,
      is_confirmed: false,
      invisible: false
    })
    |> Pleroma.Repo.chunk_stream(500)
    |> Stream.each(&Pleroma.User.maybe_send_confirmation_email(&1))
    |> Stream.run()
  end
end
