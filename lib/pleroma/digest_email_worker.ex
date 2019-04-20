defmodule Pleroma.DigestEmailWorker do
  import Ecto.Query
  require Logger

  # alias Pleroma.User

  def run() do
    Logger.warn("Running digester")
    config = Application.get_env(:pleroma, :email_notifications)[:digest]
    negative_interval = -Map.fetch!(config, :interval)
    inactivity_threshold = Map.fetch!(config, :inactivity_threshold)
    inactive_users_query = Pleroma.User.list_inactive_users_query(inactivity_threshold)

    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    from(u in inactive_users_query,
      where: fragment("? #> '{\"email_notifications\",\"digest\"}' @> 'true'", u.info),
      where: u.last_digest_emailed_at < datetime_add(^now, ^negative_interval, "day"),
      select: u
    )
    |> Pleroma.Repo.all()
    |> run(:pre)
  end

  defp run(v, :pre) do
    Logger.warn("Running for #{length(v)} users")
    run(v)
  end

  defp run([]), do: :ok

  defp run([user | users]) do
    with %Swoosh.Email{} = email <- Pleroma.Emails.UserEmail.digest_email(user) do
      Logger.warn("Sending to #{user.nickname}")
      Pleroma.Emails.Mailer.deliver_async(email)
    else
      _ ->
        Logger.warn("Skipping #{user.nickname}")
    end

    Pleroma.User.touch_last_digest_emailed_at(user)

    run(users)
  end
end
