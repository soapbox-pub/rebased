defmodule Pleroma.Repo.Migrations.ConsolidateEmailQueues do
  use Ecto.Migration

  def change do
    execute(
      "UPDATE oban_jobs SET queue = 'mailer' WHERE queue in ('digest_emails', 'new_users_digest')"
    )
  end
end
