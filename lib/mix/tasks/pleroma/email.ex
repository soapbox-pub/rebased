defmodule Mix.Tasks.Pleroma.Email do
  use Mix.Task
  import Mix.Pleroma

  @shortdoc "Simple Email test"
  @moduledoc File.read!("docs/administration/CLI_tasks/email.md")

  def run(["test" | args]) do
    Mix.Pleroma.start_pleroma()
    Application.ensure_all_started(:swoosh)

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
end
