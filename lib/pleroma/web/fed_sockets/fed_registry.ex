# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.FedSockets.FedRegistry do
  @moduledoc """
  The FedRegistry stores the active FedSockets for quick retrieval.

  The storage and retrieval portion of the FedRegistry is done in process through
  elixir's `Registry` module for speed and its ability to monitor for terminated processes.

  Dropped connections will be caught by `Registry` and deleted. Since the next
  message will initiate a new connection there is no reason to try and reconnect at that point.

  Normally outside modules should have no need to call or use the FedRegistry themselves.
  """

  alias Pleroma.Web.FedSockets.FedSocket
  alias Pleroma.Web.FedSockets.SocketInfo

  require Logger

  @default_rejection_duration 15 * 60 * 1000
  @rejections :fed_socket_rejections

  @doc """
  Retrieves a FedSocket from the Registry given it's origin.

  The origin is expected to be a string identifying the endpoint "example.com" or "example2.com:8080"

  Will return:
    * {:ok, fed_socket} for working FedSockets
    * {:error, :rejected} for origins that have been tried and refused within the rejection duration interval
    * {:error, some_reason} usually :missing for unknown origins
  """
  def get_fed_socket(origin) do
    case get_registry_data(origin) do
      {:error, reason} ->
        {:error, reason}

      {:ok, %{state: :connected} = socket_info} ->
        {:ok, socket_info}
    end
  end

  @doc """
  Adds a connected FedSocket to the Registry.

  Always returns {:ok, fed_socket}
  """
  def add_fed_socket(origin, pid \\ nil) do
    origin
    |> SocketInfo.build(pid)
    |> SocketInfo.connect()
    |> add_socket_info
  end

  defp add_socket_info(%{origin: origin, state: :connected} = socket_info) do
    case Registry.register(FedSockets.Registry, origin, socket_info) do
      {:ok, _owner} ->
        clear_prior_rejection(origin)
        Logger.debug("fedsocket added: #{inspect(origin)}")

        {:ok, socket_info}

      {:error, {:already_registered, _pid}} ->
        FedSocket.close(socket_info)
        existing_socket_info = Registry.lookup(FedSockets.Registry, origin)

        {:ok, existing_socket_info}

      _ ->
        {:error, :error_adding_socket}
    end
  end

  @doc """
  Mark this origin as having rejected a connection attempt.
  This will keep it from getting additional connection attempts
  for a period of time specified in the config.

  Always returns {:ok, new_reg_data}
  """
  def set_host_rejected(uri) do
    new_reg_data =
      uri
      |> SocketInfo.origin()
      |> get_or_create_registry_data()
      |> set_to_rejected()
      |> save_registry_data()

    {:ok, new_reg_data}
  end

  @doc """
  Retrieves the FedRegistryData from the Registry given it's origin.

  The origin is expected to be a string identifying the endpoint "example.com" or "example2.com:8080"

  Will return:
    * {:ok, fed_registry_data} for known origins
    * {:error, :missing} for uniknown origins
    * {:error, :cache_error} indicating some low level runtime issues
  """
  def get_registry_data(origin) do
    case Registry.lookup(FedSockets.Registry, origin) do
      [] ->
        if is_rejected?(origin) do
          Logger.debug("previously rejected fedsocket requested")
          {:error, :rejected}
        else
          {:error, :missing}
        end

      [{_pid, %{state: :connected} = socket_info}] ->
        {:ok, socket_info}

      _ ->
        {:error, :cache_error}
    end
  end

  @doc """
  Retrieves a map of all sockets from the Registry. The keys are the origins and the values are the corresponding SocketInfo
  """
  def list_all do
    (list_all_connected() ++ list_all_rejected())
    |> Enum.into(%{})
  end

  defp list_all_connected do
    FedSockets.Registry
    |> Registry.select([{{:"$1", :_, :"$3"}, [], [{{:"$1", :"$3"}}]}])
  end

  defp list_all_rejected do
    {:ok, keys} = Cachex.keys(@rejections)

    {:ok, registry_data} =
      Cachex.execute(@rejections, fn worker ->
        Enum.map(keys, fn k -> {k, Cachex.get!(worker, k)} end)
      end)

    registry_data
  end

  defp clear_prior_rejection(origin),
    do: Cachex.del(@rejections, origin)

  defp is_rejected?(origin) do
    case Cachex.get(@rejections, origin) do
      {:ok, nil} ->
        false

      {:ok, _} ->
        true
    end
  end

  defp get_or_create_registry_data(origin) do
    case get_registry_data(origin) do
      {:error, :missing} ->
        %SocketInfo{origin: origin}

      {:ok, socket_info} ->
        socket_info
    end
  end

  defp save_registry_data(%SocketInfo{origin: origin, state: :connected} = socket_info) do
    {:ok, true} = Registry.update_value(FedSockets.Registry, origin, fn _ -> socket_info end)
    socket_info
  end

  defp save_registry_data(%SocketInfo{origin: origin, state: :rejected} = socket_info) do
    rejection_expiration =
      Pleroma.Config.get([:fed_sockets, :rejection_duration], @default_rejection_duration)

    {:ok, true} = Cachex.put(@rejections, origin, socket_info, ttl: rejection_expiration)
    socket_info
  end

  defp set_to_rejected(%SocketInfo{} = socket_info),
    do: %SocketInfo{socket_info | state: :rejected}
end
