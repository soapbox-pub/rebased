# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.BackupWorker do
  use Oban.Worker, queue: :backup, max_attempts: 1

  alias Oban.Job
  alias Pleroma.Backup

  def process(backup) do
    %{"op" => "process", "backup_id" => backup.id}
    |> new()
    |> Oban.insert()
  end

  def schedule_deletion(backup) do
    days = Pleroma.Config.get([Pleroma.Backup, :purge_after_days])
    time = 60 * 60 * 24 * days
    scheduled_at = Calendar.NaiveDateTime.add!(backup.inserted_at, time)

    %{"op" => "delete", "backup_id" => backup.id}
    |> new(scheduled_at: scheduled_at)
    |> Oban.insert()
  end

  def delete(backup) do
    %{"op" => "delete", "backup_id" => backup.id}
    |> new()
    |> Oban.insert()
  end

  def perform(%Job{args: %{"op" => "process", "backup_id" => backup_id}}) do
    with {:ok, %Backup{} = backup} <-
           backup_id |> Backup.get() |> Backup.process(),
         {:ok, _job} <- schedule_deletion(backup),
         :ok <- Backup.remove_outdated(backup) do
      {:ok, backup}
    end
  end

  def perform(%Job{args: %{"op" => "delete", "backup_id" => backup_id}}) do
    case Backup.get(backup_id) do
      %Backup{} = backup -> Backup.delete(backup)
      nil -> :ok
    end
  end
end
