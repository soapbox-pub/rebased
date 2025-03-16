# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.BackupWorker do
  use Oban.Worker, queue: :slow, max_attempts: 1

  alias Oban.Job
  alias Pleroma.Config.Getting, as: Config
  alias Pleroma.User.Backup

  @impl true
  def perform(%Job{
        args: %{"op" => "process", "backup_id" => backup_id}
      }) do
    with {_, %Backup{} = backup} <- {:get, Backup.get_by_id(backup_id)},
         {_, {:ok, updated_backup}} <- {:run, Backup.run(backup)},
         {_, {:ok, uploaded_backup}} <- {:upload, Backup.upload(updated_backup)},
         {_, {:ok, _job}} <- {:delete, Backup.schedule_delete(uploaded_backup)},
         {_, :ok} <- {:outdated, Backup.remove_outdated(uploaded_backup.user)},
         {_, :ok} <- {:email, maybe_deliver_email(uploaded_backup)} do
      {:ok, uploaded_backup}
    else
      e -> {:error, e}
    end
  end

  def perform(%Job{args: %{"op" => "delete", "backup_id" => backup_id}}) do
    case Backup.get_by_id(backup_id) do
      %Backup{} = backup -> Backup.delete_archive(backup)
      nil -> :ok
    end
  end

  @impl true
  def timeout(_job), do: Config.get([Backup, :timeout], :timer.minutes(30))

  defp has_email?(user) do
    not is_nil(user.email) and user.email != ""
  end

  defp maybe_deliver_email(backup) do
    has_mailer = Pleroma.Config.get([Pleroma.Emails.Mailer, :enabled])
    backup = backup |> Pleroma.Repo.preload(:user)

    if has_email?(backup.user) and has_mailer do
      backup
      |> Pleroma.Emails.UserEmail.backup_is_ready_email()
      |> Pleroma.Emails.Mailer.deliver()

      :ok
    else
      :ok
    end
  end
end
