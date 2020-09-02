# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.BackupWorker do
  alias Pleroma.Backup

  use Pleroma.Workers.WorkerHelper, queue: "backup"

  @impl Oban.Worker
  def perform(%Job{args: %{"op" => "process", "backup_id" => backup_id}}) do
    with {:ok, %Backup{} = backup} <-
           backup_id |> Backup.get() |> Backup.process() do
      {:ok, backup}
    end
  end
end
