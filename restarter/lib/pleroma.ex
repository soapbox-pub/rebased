defmodule Restarter.Pleroma do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_), do: {:ok, %{}}

  def handle_info(:after_boot, %{after_boot: true} = state), do: {:noreply, state}

  def handle_info(:after_boot, state) do
    restart(:pleroma)
    {:noreply, Map.put(state, :after_boot, true)}
  end

  def handle_info({:restart, delay}, state) do
    Process.sleep(delay)
    restart(:pleroma)
    {:noreply, state}
  end

  defp restart(app) do
    :ok = Application.ensure_started(app)
    :ok = Application.stop(app)
    :ok = Application.start(app)
  end
end
