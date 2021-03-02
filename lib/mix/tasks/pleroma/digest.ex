# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Digest do
  use Mix.Task
  import Mix.Pleroma

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

      shell_info("Digest email have been sent to #{nickname} (#{user.email})")
    else
      _ ->
        shell_info("Cound't find any mentions for #{nickname} since #{last_digest_emailed_at}")
    end
  end
end
