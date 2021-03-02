# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.PurgeExpiredFilter do
  @moduledoc """
  Worker which purges expired filters
  """

  use Oban.Worker, queue: :filter_expiration, max_attempts: 1, unique: [period: :infinity]

  import Ecto.Query

  alias Oban.Job
  alias Pleroma.Repo

  @spec enqueue(%{filter_id: integer(), expires_at: DateTime.t()}) ::
          {:ok, Job.t()} | {:error, Ecto.Changeset.t()}
  def enqueue(args) do
    {scheduled_at, args} = Map.pop(args, :expires_at)

    args
    |> new(scheduled_at: scheduled_at)
    |> Oban.insert()
  end

  @impl true
  def perform(%Job{args: %{"filter_id" => id}}) do
    Pleroma.Filter
    |> Repo.get(id)
    |> Repo.delete()
  end

  @spec get_expiration(pos_integer()) :: Job.t() | nil
  def get_expiration(id) do
    from(j in Job,
      where: j.state == "scheduled",
      where: j.queue == "filter_expiration",
      where: fragment("?->'filter_id' = ?", j.args, ^id)
    )
    |> Repo.one()
  end
end
