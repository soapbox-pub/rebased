defmodule Mix.Tasks.Pleroma.Digest do
  use Mix.Task
  alias Mix.Tasks.Pleroma.Common

  @shortdoc "Manages digest emails"
  @moduledoc """
  Manages digest emails

  ## Send digest email since given date (user registration date by default)
  ignoring user activity status.

  ``mix pleroma.digest test <nickname> <since_date>``

  Example: ``mix pleroma.digest test donaldtheduck 2019-05-20``
  """
  def run(["test", nickname | opts]) do
    Common.start_pleroma()

    user = Pleroma.User.get_by_nickname(nickname)

    last_digest_emailed_at =
      with [date] <- opts,
           {:ok, datetime} <- Timex.parse(date, "{YYYY}-{0M}-{0D}") do
        datetime
      else
        _ -> user.inserted_at
      end

    patched_user = %{user | last_digest_emailed_at: last_digest_emailed_at}

    :ok = Pleroma.DigestEmailWorker.run([patched_user])
    Mix.shell().info("Digest email have been sent to #{nickname} (#{user.email})")
  end
end
