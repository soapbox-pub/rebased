# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Search.Indexer do
  import Mix.Pleroma
  import Ecto.Query

  alias Pleroma.Workers.SearchIndexingWorker

  def run(["create_index"]) do
    start_pleroma()

    with :ok <- Pleroma.Config.get([Pleroma.Search, :module]).create_index() do
      IO.puts("Index created")
    else
      e -> IO.puts("Could not create index: #{inspect(e)}")
    end
  end

  def run(["drop_index"]) do
    start_pleroma()

    with :ok <- Pleroma.Config.get([Pleroma.Search, :module]).drop_index() do
      IO.puts("Index dropped")
    else
      e -> IO.puts("Could not drop index: #{inspect(e)}")
    end
  end

  def run(["index" | options]) do
    {options, [], []} =
      OptionParser.parse(
        options,
        strict: [
          limit: :integer
        ]
      )

    start_pleroma()

    limit = Keyword.get(options, :limit, 100_000)

    per_step = 1000
    chunks = max(div(limit, per_step), 1)

    1..chunks
    |> Enum.each(fn step ->
      q =
        from(a in Pleroma.Activity,
          limit: ^per_step,
          offset: ^per_step * (^step - 1),
          select: [:id],
          order_by: [desc: :id]
        )

      {:ok, ids} =
        Pleroma.Repo.transaction(fn ->
          Pleroma.Repo.stream(q, timeout: :infinity)
          |> Enum.map(fn a ->
            a.id
          end)
        end)

      IO.puts("Got #{length(ids)} activities, adding to indexer")

      ids
      |> Enum.chunk_every(100)
      |> Enum.each(fn chunk ->
        IO.puts("Adding #{length(chunk)} activities to indexing queue")

        chunk
        |> Enum.map(fn id ->
          SearchIndexingWorker.new(%{"op" => "add_to_index", "activity" => id})
        end)
        |> Oban.insert_all()
      end)
    end)
  end
end
