# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.FedSockets.FetchRegistry do
  @moduledoc """
  The FetchRegistry acts as a broker for fetch requests and return values.
  This allows calling processes to block while waiting for a reply.
  It doesn't impose it's own process instead using `Cachex` to handle fetches in process, allowing
  multi threaded processes to avoid bottlenecking.

  Normally outside modules will have no need to call or use the FetchRegistry themselves.

  The `Cachex` parameters can be controlled from the config. Since exact timeout intervals
  aren't necessary the following settings are used by default:

  config :pleroma, :fed_sockets,
    fed_socket_fetches: [
      default: 12_000,
      interval: 3_000,
      lazy: false
    ]

  """

  defmodule FetchRegistryData do
    defstruct uuid: nil,
              sent_json: nil,
              received_json: nil,
              sent_at: nil,
              received_at: nil
  end

  alias Ecto.UUID

  require Logger

  @fetches :fed_socket_fetches

  @doc """
  Registers a json request wth the FetchRegistry and returns the identifying UUID.
  """
  def register_fetch(json) do
    %FetchRegistryData{uuid: uuid} =
      json
      |> new_registry_data
      |> save_registry_data

    uuid
  end

  @doc """
  Reports on the status of a Fetch given the identifying UUID.

  Will return
    * {:ok, fetched_object} if a fetch has completed
    * {:error, :waiting} if a fetch is still pending
    * {:error, other_error} usually :missing to indicate a fetch that has timed out
  """
  def check_fetch(uuid) do
    case get_registry_data(uuid) do
      {:ok, %FetchRegistryData{received_at: nil}} ->
        {:error, :waiting}

      {:ok, %FetchRegistryData{} = reg_data} ->
        {:ok, reg_data}

      e ->
        e
    end
  end

  @doc """
  Retrieves the response to a fetch given the identifying UUID.
  The completed fetch will be deleted from the FetchRegistry

  Will return
    * {:ok, fetched_object} if a fetch has completed
    * {:error, :waiting} if a fetch is still pending
    * {:error, other_error} usually :missing to indicate a fetch that has timed out
  """
  def pop_fetch(uuid) do
    case check_fetch(uuid) do
      {:ok, %FetchRegistryData{received_json: received_json}} ->
        delete_registry_data(uuid)
        {:ok, received_json}

      e ->
        e
    end
  end

  @doc """
  This is called to register a fetch has returned.
  It expects the result data along with the UUID that was sent in the request

  Will return the fetched object or :error
  """
  def register_fetch_received(uuid, data) do
    case get_registry_data(uuid) do
      {:ok, %FetchRegistryData{received_at: nil} = reg_data} ->
        reg_data
        |> set_fetch_received(data)
        |> save_registry_data()

      {:ok, %FetchRegistryData{} = reg_data} ->
        Logger.warn("tried to add fetched data twice - #{uuid}")
        reg_data

      {:error, _} ->
        Logger.warn("Error adding fetch to registry - #{uuid}")
        :error
    end
  end

  defp new_registry_data(json) do
    %FetchRegistryData{
      uuid: UUID.generate(),
      sent_json: json,
      sent_at: :erlang.monotonic_time(:millisecond)
    }
  end

  defp get_registry_data(origin) do
    case Cachex.get(@fetches, origin) do
      {:ok, nil} ->
        {:error, :missing}

      {:ok, reg_data} ->
        {:ok, reg_data}

      _ ->
        {:error, :cache_error}
    end
  end

  defp set_fetch_received(%FetchRegistryData{} = reg_data, data),
    do: %FetchRegistryData{
      reg_data
      | received_at: :erlang.monotonic_time(:millisecond),
        received_json: data
    }

  defp save_registry_data(%FetchRegistryData{uuid: uuid} = reg_data) do
    {:ok, true} = Cachex.put(@fetches, uuid, reg_data)
    reg_data
  end

  defp delete_registry_data(origin),
    do: {:ok, true} = Cachex.del(@fetches, origin)
end
