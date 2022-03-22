# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Search.Meilisearch do
  require Pleroma.Constants

  import Mix.Pleroma
  import Ecto.Query

  import Pleroma.Search.Meilisearch,
    only: [meili_post: 2, meili_put: 2, meili_get: 1, meili_delete!: 1]

  def run(["index"]) do
    start_pleroma()

    meili_version =
      (
        {:ok, result} = meili_get("/version")

        result["pkgVersion"]
      )

    # The ranking rule syntax was changed but nothing about that is mentioned in the changelog
    if not Version.match?(meili_version, ">= 0.25.0") do
      raise "Meilisearch <0.24.0 not supported"
    end

    {:ok, _} =
      meili_post(
        "/indexes/objects/settings/ranking-rules",
        [
          "published:desc",
          "words",
          "exactness",
          "proximity",
          "typo",
          "attribute",
          "sort"
        ]
      )

    {:ok, _} =
      meili_post(
        "/indexes/objects/settings/searchable-attributes",
        [
          "content"
        ]
      )

    IO.puts("Created indices. Starting to insert posts.")

    chunk_size = Pleroma.Config.get([Pleroma.Search.Meilisearch, :initial_indexing_chunk_size])

    Pleroma.Repo.transaction(
      fn ->
        query =
          from(Pleroma.Object,
            # Only index public and unlisted posts which are notes and have some text
            where:
              fragment("data->>'type' = 'Note'") and
                (fragment("data->'to' \\? ?", ^Pleroma.Constants.as_public()) or
                   fragment("data->'cc' \\? ?", ^Pleroma.Constants.as_public())),
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
            meili_put(
              "/indexes/objects/documents",
              objects
            )

          with {:ok, res} <- result do
            if not Map.has_key?(res, "updateId") do
              IO.puts("\nFailed to index: #{inspect(result)}")
            end
          else
            e -> IO.puts("\nFailed to index due to network error: #{inspect(e)}")
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

  def run(["show-keys", master_key]) do
    start_pleroma()

    endpoint = Pleroma.Config.get([Pleroma.Search.Meilisearch, :url])

    {:ok, result} =
      Pleroma.HTTP.get(
        Path.join(endpoint, "/keys"),
        [{"Authorization", "Bearer #{master_key}"}]
      )

    decoded = Jason.decode!(result.body)

    if decoded["results"] do
      Enum.each(decoded["results"], fn %{"description" => desc, "key" => key} ->
        IO.puts("#{desc}: #{key}")
      end)
    else
      IO.puts("Error fetching the keys, check the master key is correct: #{inspect(decoded)}")
    end
  end

  def run(["stats"]) do
    start_pleroma()

    {:ok, result} = meili_get("/indexes/objects/stats")
    IO.puts("Number of entries: #{result["numberOfDocuments"]}")
    IO.puts("Indexing? #{result["isIndexing"]}")
  end
end
