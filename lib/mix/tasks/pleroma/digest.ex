defmodule Mix.Tasks.Pleroma.Digest do
  use Mix.Task

  @shortdoc "Manages digest emails"
  @moduledoc File.read!("docs/administration/CLI_tasks/digest.md")

  def run(["test", nickname | opts]) do
    Mix.Pleroma.start_pleroma()

    user = Pleroma.User.get_by_nickname(nickname)

    last_digest_emailed_at =
      with [date] <- opts,
           {:ok, datetime} <- Timex.parse(date, "{YYYY}-{0M}-{0D}") do
        datetime
      else
        _ -> user.inserted_at
      end

    patched_user = %{user | last_digest_emailed_at: last_digest_emailed_at}

    with %Swoosh.Email{} = email <- Pleroma.Emails.UserEmail.digest_email(patched_user) do
      {:ok, _} = Pleroma.Emails.Mailer.deliver(email)

      Mix.shell().info("Digest email have been sent to #{nickname} (#{user.email})")
    else
      _ ->
        Mix.shell().info(
          "Cound't find any mentions for #{nickname} since #{last_digest_emailed_at}"
        )
    end
  end
end
