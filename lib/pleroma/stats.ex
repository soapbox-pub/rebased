# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Stats do
  import Ecto.Query
  alias Pleroma.Repo
  alias Pleroma.User

  use GenServer

  @interval 1000 * 60 * 60

  def start_link(_) do
    GenServer.start_link(__MODULE__, initial_data(), name: __MODULE__)
  end

  def force_update do
    GenServer.call(__MODULE__, :force_update)
  end

  def get_stats do
    %{stats: stats} = GenServer.call(__MODULE__, :get_state)

    stats
  end

  def get_peers do
    %{peers: peers} = GenServer.call(__MODULE__, :get_state)

    peers
  end

  def init(args) do
    Process.send(self(), :run_update, [])
    {:ok, args}
  end

  def handle_call(:force_update, _from, _state) do
    new_stats = get_stat_data()
    {:reply, new_stats, new_stats}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_info(:run_update, _state) do
    new_stats = get_stat_data()

    Process.send_after(self(), :run_update, @interval)
    {:noreply, new_stats}
  end

  defp initial_data do
    %{peers: [], stats: %{}}
  end

  defp get_stat_data do
    peers =
      from(
        u in User,
        select: fragment("distinct split_part(?, '@', 2)", u.nickname),
        where: u.local != ^true
      )
      |> Repo.all()
      |> Enum.filter(& &1)

    domain_count = Enum.count(peers)

    status_count = Repo.aggregate(User.Query.build(%{local: true}), :sum, :note_count)

    user_count = Repo.aggregate(User.Query.build(%{local: true, active: true}), :count, :id)

    %{
      peers: peers,
      stats: %{domain_count: domain_count, status_count: status_count, user_count: user_count}
    }
  end
end
