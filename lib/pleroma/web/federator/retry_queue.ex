defmodule Pleroma.Web.Federator.RetryQueue do
  use GenServer
  alias Pleroma.Web.{WebFinger, Websub}
  alias Pleroma.Web.ActivityPub.ActivityPub
  require Logger

  @websub Application.get_env(:pleroma, :websub)
  @ostatus Application.get_env(:pleroma, :websub)
  @httpoison Application.get_env(:pleroma, :websub)
  @instance Application.get_env(:pleroma, :websub)
  # initial timeout, 5 min
  @initial_timeout 30_000
  @max_retries 5

  def init(args) do
    {:ok, args}
  end

  def start_link() do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def enqueue(data, transport, retries \\ 0) do
    GenServer.cast(__MODULE__, {:maybe_enqueue, data, transport, retries + 1})
  end

  def handle_cast({:maybe_enqueue, data, transport, retries}, state) do
    if retries > @max_retries do
      Logger.debug("Maximum retries reached on #{inspect(data)}")
      {:noreply, state}
    else
      Process.send_after(
        __MODULE__,
        {:send, data, transport, retries},
        growth_function(retries)
      )

      {:noreply, state}
    end
  end

  def handle_info({:send, %{topic: topic} = data, :websub, retries}, state) do
    Logger.debug("RetryQueue: Retrying to send object #{topic}")

    case Websub.publish_one(data) do
      {:ok, _} ->
        {:noreply, state}

      {:error, reason} ->
        enqueue(data, :websub, retries)
        {:noreply, state}
    end
  end

  def handle_info({:send, %{id: id} = data, :activitypub, retries}, state) do
    Logger.debug("RetryQueue: Retrying to send object #{id}")

    case ActivityPub.publish_one(data) do
      {:ok, _} ->
        {:noreply, state}

      {:error, reason} ->
        enqueue(data, :activitypub, retries)
        {:noreply, state}
    end
  end

  def handle_info(unknown, state) do
    Logger.debug("RetryQueue: don't know what to do with #{inspect(unknown)}, ignoring")
    {:noreply, state}
  end

  defp growth_function(retries) do
    round(@initial_timeout * :math.pow(retries, 3))
  end
end
