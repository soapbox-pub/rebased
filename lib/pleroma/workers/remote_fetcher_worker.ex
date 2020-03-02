# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.RemoteFetcherWorker do
  alias Pleroma.Object.Fetcher

  use Pleroma.Workers.WorkerHelper, queue: "remote_fetcher"

  @impl Oban.Worker
  def perform(
        %{
          "op" => "fetch_remote",
          "id" => id
        } = args,
        _job
      ) do
    {:ok, _object} = Fetcher.fetch_object_from_id(id, depth: args["depth"])
  end
end
