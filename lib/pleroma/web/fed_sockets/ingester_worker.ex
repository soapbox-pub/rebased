# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.FedSockets.IngesterWorker do
  use Pleroma.Workers.WorkerHelper, queue: "ingestion_queue"
  require Logger

  alias Pleroma.Web.Federator

  @impl Oban.Worker
  def perform(%Job{args: %{"op" => "ingest", "object" => ingestee}}) do
    try do
      ingestee
      |> Jason.decode!()
      |> do_ingestion()
    rescue
      e ->
        Logger.error("IngesterWorker error - #{inspect(e)}")
        e
    end
  end

  defp do_ingestion(params) do
    case Federator.incoming_ap_doc(params) do
      {:error, reason} ->
        {:error, reason}

      {:ok, object} ->
        {:ok, object}
    end
  end
end
