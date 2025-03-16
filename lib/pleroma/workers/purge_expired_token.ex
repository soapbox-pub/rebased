# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.PurgeExpiredToken do
  @moduledoc """
  Worker which purges expired OAuth tokens
  """

  use Oban.Worker, queue: :background, max_attempts: 1

  @impl true
  def perform(%Oban.Job{args: %{"token_id" => id, "mod" => module}}) do
    module
    |> String.to_existing_atom()
    |> Pleroma.Repo.get(id)
    |> Pleroma.Repo.delete()
  end

  @impl true
  def timeout(_job), do: :timer.seconds(5)
end
