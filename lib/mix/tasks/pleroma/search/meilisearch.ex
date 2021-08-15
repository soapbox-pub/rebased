# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Search.Meilisearch do
  import Mix.Pleroma

  import Ecto.Query

  def run(["index"]) do
    start_pleroma()

    endpoint = Pleroma.Config.get([Pleroma.Search.Meilisearch, :url])

    Pleroma.Repo.chunk_stream(
      from(Pleroma.Object,
        limit: 200,
        where: fragment("data->>'type' = 'Note'") and fragment("LENGTH(data->>'source') > 0")
      ),
      100,
      :batches
    )
    |> Stream.map(fn objects ->
      Enum.map(objects, fn object ->
        data = object.data
        %{id: object.id, source: data["source"], ap: data["id"]}
      end)
    end)
    |> Stream.each(fn activities ->
      {:ok, _} =
        Pleroma.HTTP.post(
          "#{endpoint}/indexes/objects/documents",
          Jason.encode!(activities)
        )
    end)
    |> Stream.run()
  end
end
