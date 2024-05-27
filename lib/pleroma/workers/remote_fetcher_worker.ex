# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.RemoteFetcherWorker do
  alias Pleroma.Object.Fetcher

  use Pleroma.Workers.WorkerHelper, queue: "background"

  @impl Oban.Worker
  def perform(%Job{args: %{"op" => "fetch_remote", "id" => id} = args}) do
    case Fetcher.fetch_object_from_id(id, depth: args["depth"]) do
      {:ok, _object} ->
        :ok

      {:error, :forbidden} ->
        {:discard, :forbidden}

      {:error, :not_found} ->
        {:discard, :not_found}

      {:error, :allowed_depth} ->
        {:discard, :allowed_depth}

      {:error, _} = e ->
        e

      e ->
        {:error, e}
    end
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.seconds(10)
end
