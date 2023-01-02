# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.MoveActivityExpirationsToOban do
  use Ecto.Migration

  import Ecto.Query, only: [from: 2]

  def change do
    Pleroma.Config.Oban.warn()

    Application.ensure_all_started(:oban)

    Supervisor.start_link([{Oban, Pleroma.Config.get(Oban)}],
      strategy: :one_for_one,
      name: Pleroma.Supervisor
    )

    from(e in "activity_expirations",
      select: %{id: e.id, activity_id: e.activity_id, scheduled_at: e.scheduled_at}
    )
    |> Pleroma.Repo.stream()
    |> Stream.each(fn expiration ->
      with {:ok, expires_at} <- DateTime.from_naive(expiration.scheduled_at, "Etc/UTC") do
        Pleroma.Workers.PurgeExpiredActivity.enqueue(%{
          activity_id: FlakeId.to_string(expiration.activity_id),
          expires_at: expires_at
        })
      end
    end)
    |> Stream.run()
  end
end
