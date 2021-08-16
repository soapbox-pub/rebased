# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Search.Meilisearch do
  require Logger
  require Pleroma.Constants

  import Mix.Pleroma
  import Ecto.Query

  def run(["index"]) do
    start_pleroma()

    endpoint = Pleroma.Config.get([Pleroma.Search.Meilisearch, :url])

    {:ok, _} =
      Pleroma.HTTP.post(
        "#{endpoint}/indexes/objects/settings/ranking-rules",
        Jason.encode!([
          "desc(published)",
          "typo",
          "words",
          "proximity",
          "attribute",
          "wordsPosition",
          "exactness"
        ])
      )

    chunk_size = 100_000

    Pleroma.Repo.transaction(
      fn ->
        Pleroma.Repo.stream(
          from(Pleroma.Object,
            # Only index public posts which are notes and have some text
            where:
              fragment("data->>'type' = 'Note'") and
                fragment("LENGTH(data->>'content') > 0") and
                fragment("data->'to' \\? ?", ^Pleroma.Constants.as_public()),
            order_by: [desc: fragment("data->'published'")]
          ),
          timeout: :infinity
        )
        |> Stream.chunk_every(chunk_size)
        |> Stream.transform(0, fn objects, acc ->
          new_acc = acc + Enum.count(objects)

          IO.puts("Indexed #{new_acc} entries")

          {[objects], new_acc}
        end)
        |> Stream.map(fn objects ->
          Enum.map(objects, fn object ->
            data = object.data

            {:ok, published, _} = DateTime.from_iso8601(data["published"])
            {:ok, content} = FastSanitize.strip_tags(data["content"])

            %{
              id: object.id,
              content: content,
              ap: data["id"],
              published: published |> DateTime.to_unix()
            }
          end)
        end)
        |> Stream.each(fn objects ->
          {:ok, result} =
            Pleroma.HTTP.post(
              "#{endpoint}/indexes/objects/documents",
              Jason.encode!(objects)
            )

          if not Map.has_key?(Jason.decode!(result.body), "updateId") do
            IO.puts("Failed to index: #{result}")
          end
        end)
        |> Stream.run()
      end,
      timeout: :infinity
    )
  end

  def run(["clear"]) do
    start_pleroma()

    endpoint = Pleroma.Config.get([Pleroma.Search.Meilisearch, :url])

    {:ok, _} = Pleroma.HTTP.request(:delete, "#{endpoint}/indexes/objects", "", [], [])
  end
end
