defmodule Pleroma.Gun.ConnectionPool.Worker do
  alias Pleroma.Gun
  use GenServer, restart: :temporary

  @registry Pleroma.Gun.ConnectionPool

  def start_link([key | _] = opts) do
    GenServer.start_link(__MODULE__, opts, name: {:via, Registry, {@registry, key}})
  end

  @impl true
  def init([key, uri, opts, client_pid]) do
    with {:ok, conn_pid} <- Gun.Conn.open(uri, opts),
         Process.link(conn_pid) do
      time = :os.system_time(:second)

      {_, _} =
        Registry.update_value(@registry, key, fn _ ->
          {conn_pid, [client_pid], 1, time}
        end)

      send(client_pid, {:conn_pid, conn_pid})
      {:ok, %{key: key, timer: nil}, :hibernate}
    else
      err -> {:stop, err}
    end
  end

  @impl true
  def handle_cast({:add_client, client_pid, send_pid_back}, %{key: key} = state) do
    time = :os.system_time(:second)

    {{conn_pid, _, _, _}, _} =
      Registry.update_value(@registry, key, fn {conn_pid, used_by, crf, last_reference} ->
        {conn_pid, [client_pid | used_by], crf(time - last_reference, crf), time}
      end)

    if send_pid_back, do: send(client_pid, {:conn_pid, conn_pid})

    state =
      if state.timer != nil do
        Process.cancel_timer(state[:timer])
        %{state | timer: nil}
      else
        state
      end

    {:noreply, state, :hibernate}
  end

  @impl true
  def handle_cast({:remove_client, client_pid}, %{key: key} = state) do
    {{_conn_pid, used_by, _crf, _last_reference}, _} =
      Registry.update_value(@registry, key, fn {conn_pid, used_by, crf, last_reference} ->
        {conn_pid, List.delete(used_by, client_pid), crf, last_reference}
      end)

    timer =
      if used_by == [] do
        max_idle = Pleroma.Config.get([:connections_pool, :max_idle_time], 30_000)
        Process.send_after(self(), :idle_close, max_idle)
      else
        nil
      end

    {:noreply, %{state | timer: timer}, :hibernate}
  end

  @impl true
  def handle_info(:idle_close, state) do
    # Gun monitors the owner process, and will close the connection automatically
    # when it's terminated
    {:stop, :normal, state}
  end

  # Gracefully shutdown if the connection got closed without any streams left
  @impl true
  def handle_info({:gun_down, _pid, _protocol, _reason, []}, state) do
    {:stop, :normal, state}
  end

  # Otherwise, shutdown with an error
  @impl true
  def handle_info({:gun_down, _pid, _protocol, _reason, _killed_streams} = down_message, state) do
    {:stop, {:error, down_message}, state}
  end

  # LRFU policy: https://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.55.1478
  defp crf(time_delta, prev_crf) do
    1 + :math.pow(0.5, time_delta / 100) * prev_crf
  end
end
