# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Search.Meilisearch do
  require Logger
  require Pleroma.Constants

  import Mix.Pleroma
  import Ecto.Query

  import Pleroma.Search.Meilisearch, only: [meili_post!: 2, meili_delete!: 1, meili_get!: 1]

  def run(["index"]) do
    start_pleroma()

    meili_post!(
      "/indexes/objects/settings/ranking-rules",
      [
        "desc(published)",
        "words",
        "exactness",
        "proximity",
        "wordsPosition",
        "typo",
        "attribute"
      ]
    )

    meili_post!(
      "/indexes/objects/settings/searchable-attributes",
      [
        "content"
      ]
    )

    chunk_size = 10_000

    Pleroma.Repo.transaction(
      fn ->
        query =
          from(Pleroma.Object,
            # Only index public posts which are notes and have some text
            where:
              fragment("data->>'type' = 'Note'") and
                fragment("LENGTH(data->>'content') > 0") and
                fragment("data->'to' \\? ?", ^Pleroma.Constants.as_public()),
            order_by: [desc: fragment("data->'published'")]
          )

        count = query |> Pleroma.Repo.aggregate(:count, :data)
        IO.puts("Entries to index: #{count}")

        Pleroma.Repo.stream(
          query,
          timeout: :infinity
        )
        |> Stream.map(&Pleroma.Search.Meilisearch.object_to_search_data/1)
        |> Stream.filter(fn o -> not is_nil(o) end)
        |> Stream.chunk_every(chunk_size)
        |> Stream.transform(0, fn objects, acc ->
          new_acc = acc + Enum.count(objects)

          # Reset to the beginning of the line and rewrite it
          IO.write("\r")
          IO.write("Indexed #{new_acc} entries")

          {[objects], new_acc}
        end)
        |> Stream.each(fn objects ->
          result =
            meili_post!(
              "/indexes/objects/documents",
              objects
            )

          if not Map.has_key?(result, "updateId") do
            IO.puts("Failed to index: #{inspect(result)}")
          end
        end)
        |> Stream.run()
      end,
      timeout: :infinity
    )

    IO.write("\n")
  end

  def run(["clear"]) do
    start_pleroma()

    meili_delete!("/indexes/objects/documents")
  end

  def run(["show-private-key", master_key]) do
    start_pleroma()

    endpoint = Pleroma.Config.get([Pleroma.Search.Meilisearch, :url])

    {:ok, result} =
      Pleroma.HTTP.get(
        Path.join(endpoint, "/keys"),
        [{"X-Meili-API-Key", master_key}]
      )

    decoded = Jason.decode!(result.body)

    if decoded["private"] do
      IO.puts(decoded["private"])
    else
      IO.puts("Error fetching the key, check the master key is correct: #{inspect(decoded)}")
    end
  end

  def run(["stats"]) do
    start_pleroma()

    result = meili_get!("/indexes/objects/stats")
    IO.puts("Number of entries: #{result["numberOfDocuments"]}")
    IO.puts("Indexing? #{result["isIndexing"]}")
  end
end
