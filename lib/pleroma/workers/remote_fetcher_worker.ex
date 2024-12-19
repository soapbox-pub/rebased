# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.RemoteFetcherWorker do
  alias Pleroma.Object.Fetcher

  use Oban.Worker, queue: :background, unique: [period: :infinity]

  @impl true
  def perform(%Job{args: %{"op" => "fetch_remote", "id" => id} = args}) do
    case Fetcher.fetch_object_from_id(id, depth: args["depth"]) do
      {:ok, _object} ->
        :ok

      {:allowed_depth, false} ->
        {:cancel, :allowed_depth}

      {:containment, reason} ->
        {:cancel, reason}

      {:transmogrifier, reason} ->
        {:cancel, reason}

      {:fetch, {:error, :forbidden = reason}} ->
        {:cancel, reason}

      {:fetch, {:error, :not_found = reason}} ->
        {:cancel, reason}

      {:fetch, {:error, {:content_type, _}} = reason} ->
        {:cancel, reason}

      {:fetch, {:error, reason}} ->
        {:error, reason}

      {:error, _} = e ->
        e
    end
  end

  @impl true
  def timeout(_job), do: :timer.seconds(15)
end
