defmodule Restarter.Pleroma do
  use GenServer

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_), do: {:ok, %{need_reboot?: false}}

  def need_reboot? do
    GenServer.call(__MODULE__, :need_reboot?)
  end

  def need_reboot do
    GenServer.cast(__MODULE__, :need_reboot)
  end

  def refresh do
    GenServer.cast(__MODULE__, :refresh)
  end

  def restart(env, delay) do
    GenServer.cast(__MODULE__, {:restart, env, delay})
  end

  def restart_after_boot(env) do
    GenServer.cast(__MODULE__, {:after_boot, env})
  end

  def handle_call(:need_reboot?, _from, state) do
    {:reply, state[:need_reboot?], state}
  end

  def handle_cast(:refresh, _state) do
    {:noreply, %{need_reboot?: false}}
  end

  def handle_cast(:need_reboot, %{need_reboot?: true} = state), do: {:noreply, state}

  def handle_cast(:need_reboot, state) do
    {:noreply, Map.put(state, :need_reboot?, true)}
  end

  def handle_cast({:restart, :test, _}, state) do
    Logger.warn("pleroma restarted")
    {:noreply, Map.put(state, :need_reboot?, false)}
  end

  def handle_cast({:restart, _, delay}, state) do
    Process.sleep(delay)
    do_restart(:pleroma)
    {:noreply, Map.put(state, :need_reboot?, false)}
  end

  def handle_cast({:after_boot, _}, %{after_boot: true} = state), do: {:noreply, state}

  def handle_cast({:after_boot, :test}, state) do
    Logger.warn("pleroma restarted")
    {:noreply, Map.put(state, :after_boot, true)}
  end

  def handle_cast({:after_boot, _}, state) do
    do_restart(:pleroma)
    {:noreply, Map.put(state, :after_boot, true)}
  end

  defp do_restart(app) do
    :ok = Application.ensure_started(app)
    :ok = Application.stop(app)
    :ok = Application.start(app)
  end
end
