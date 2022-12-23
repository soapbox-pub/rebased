# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.DeleteNotificationWithoutActivity do
  use Ecto.Migration

  import Ecto.Query
  alias Pleroma.Repo

  def up do
    from(
      q in Pleroma.Notification,
      left_join: c in assoc(q, :activity),
      select: %{id: type(q.id, :integer)},
      where: is_nil(c.id)
    )
    |> Repo.chunk_stream(1_000, :batches)
    |> Stream.each(fn records ->
      notification_ids = Enum.map(records, fn %{id: id} -> id end)

      Repo.delete_all(
        from(n in "notifications",
          where: n.id in ^notification_ids
        )
      )
    end)
    |> Stream.run()
  end

  def down do
    :ok
  end
end
