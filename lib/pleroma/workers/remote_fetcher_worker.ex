# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.RemoteFetcherWorker do
  alias Pleroma.Object.Fetcher

  use Oban.Worker, queue: :background

  @impl true
  def perform(%Job{args: %{"op" => "fetch_remote", "id" => id} = args}) do
    case Fetcher.fetch_object_from_id(id, depth: args["depth"]) do
      {:ok, _object} ->
        :ok

      {:reject, reason} ->
        {:cancel, reason}

      {:error, :forbidden} ->
        {:cancel, :forbidden}

      {:error, :not_found} ->
        {:cancel, :not_found}

      {:error, :allowed_depth} ->
        {:cancel, :allowed_depth}

      {:error, _} = e ->
        e
    end
  end

  @impl true
  def timeout(_job), do: :timer.seconds(15)
end
