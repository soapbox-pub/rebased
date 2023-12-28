# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.RemoteFetcherWorker do
  alias Pleroma.Instances
  alias Pleroma.Object.Fetcher

  use Pleroma.Workers.WorkerHelper, queue: "remote_fetcher"

  @impl Oban.Worker
  def perform(%Job{args: %{"op" => "fetch_remote", "id" => id} = args}) do
    if Instances.reachable?(id) do
      case Fetcher.fetch_object_from_id(id, depth: args["depth"]) do
        {:ok, _object} ->
          :ok

        {:error, :forbidden} ->
          {:cancel, :forbidden}

        {:error, :not_found} ->
          {:cancel, :not_found}

        _ ->
          :error
      end
    else
      {:cancel, "Unreachable instance"}
    end
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.seconds(10)
end
