# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.RepoStreamer do
  alias Pleroma.Repo
  import Ecto.Query

  def chunk_stream(query, chunk_size) do
    Stream.unfold(0, fn
      :halt ->
        {[], :halt}

      last_id ->
        query
        |> order_by(asc: :id)
        |> where([r], r.id > ^last_id)
        |> limit(^chunk_size)
        |> Repo.all()
        |> case do
          [] ->
            {[], :halt}

          records ->
            last_id = List.last(records).id
            {records, last_id}
        end
    end)
    |> Stream.take_while(fn
      [] -> false
      _ -> true
    end)
  end
end
