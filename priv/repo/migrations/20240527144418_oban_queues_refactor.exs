defmodule Pleroma.Repo.Migrations.ObanQueuesRefactor do
  use Ecto.Migration

  @changed_queues [
    {"attachments_cleanup", "slow"},
    {"check_domain_resolve", "slow"},
    {"mailer", "background"},
    {"mute_expire", "background"},
    {"poll_notifications", "background"},
    {"activity_expiration", "slow"},
    {"filter_expiration", "background"},
    {"token_expiration", "background"},
    {"remote_fetcher", "background"},
    {"rich_media_expiration", "background"}
  ]

  def up do
    Enum.each(@changed_queues, fn {old, new} ->
      execute("UPDATE oban_jobs SET queue = '#{new}' WHERE queue = '#{old}';")
    end)

    # Handled special as reverting this would not be ideal and leaving it is harmless
    execute(
      "UPDATE oban_jobs SET queue = 'federator_outgoing' WHERE queue = 'scheduled_activities';"
    )
  end

  def down do
    # Just move all slow queue jobs to background queue if we are reverting
    # as the slow queue will not be processing jobs
    execute("UPDATE oban_jobs SET queue = 'background' WHERE queue = 'slow';")
  end
end
