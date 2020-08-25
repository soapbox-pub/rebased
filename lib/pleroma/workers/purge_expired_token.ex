# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.PurgeExpiredOAuthToken do
  @moduledoc """
  Worker which purges expired OAuth tokens
  """

  use Oban.Worker, queue: :oauth_token_expiration, max_attempts: 1

  @spec enqueue(%{token_id: integer(), valid_until: DateTime.t()}) ::
          {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def enqueue(args) do
    {scheduled_at, args} = Map.pop(args, :valid_until)

    args
    |> __MODULE__.new(scheduled_at: scheduled_at)
    |> Oban.insert()
  end

  @impl true
  def perform(%Oban.Job{args: %{"token_id" => id}}) do
    Pleroma.Web.OAuth.Token
    |> Pleroma.Repo.get(id)
    |> Pleroma.Repo.delete()
  end
end
