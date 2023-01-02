# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo do
  use Ecto.Repo,
    otp_app: :pleroma,
    adapter: Ecto.Adapters.Postgres,
    migration_timestamps: [type: :naive_datetime_usec]

  import Ecto.Query
  require Logger

  defmodule Instrumenter, do: use(Prometheus.EctoInstrumenter)

  @doc """
  Dynamically loads the repository url from the
  DATABASE_URL environment variable.
  """
  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, System.get_env("DATABASE_URL"))}
  end

  @doc "find resource based on prepared query"
  @spec find_resource(Ecto.Query.t()) :: {:ok, struct()} | {:error, :not_found}
  def find_resource(%Ecto.Query{} = query) do
    case __MODULE__.one(query) do
      nil -> {:error, :not_found}
      resource -> {:ok, resource}
    end
  end

  def find_resource(_query), do: {:error, :not_found}

  @doc """
  Gets association from cache or loads if need

  ## Examples

    iex> Repo.get_assoc(token, :user)
    %User{}

  """
  @spec get_assoc(struct(), atom()) :: {:ok, struct()} | {:error, :not_found}
  def get_assoc(resource, association) do
    case __MODULE__.preload(resource, association) do
      %{^association => assoc} when not is_nil(assoc) -> {:ok, assoc}
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Returns a lazy enumerable that emits all entries from the data store matching the given query.

  `returns_as` use to group records. use the `batches` option to fetch records in bulk.

  ## Examples

  # fetch records one-by-one
  iex> Pleroma.Repo.chunk_stream(Pleroma.Activity.Queries.by_actor(ap_id), 500)

  # fetch records in bulk
  iex> Pleroma.Repo.chunk_stream(Pleroma.Activity.Queries.by_actor(ap_id), 500, :batches)
  """
  @spec chunk_stream(Ecto.Query.t(), integer(), atom()) :: Enumerable.t()
  def chunk_stream(query, chunk_size, returns_as \\ :one, query_options \\ []) do
    # We don't actually need start and end functions of resource streaming,
    # but it seems to be the only way to not fetch records one-by-one and
    # have individual records be the elements of the stream, instead of
    # lists of records
    Stream.resource(
      fn -> 0 end,
      fn
        last_id ->
          query
          |> order_by(asc: :id)
          |> where([r], r.id > ^last_id)
          |> limit(^chunk_size)
          |> all(query_options)
          |> case do
            [] ->
              {:halt, last_id}

            records ->
              last_id = List.last(records).id

              if returns_as == :one do
                {records, last_id}
              else
                {[records], last_id}
              end
          end
      end,
      fn _ -> :ok end
    )
  end
end
