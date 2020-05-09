# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Stats do
  import Ecto.Query
  alias Pleroma.CounterCache
  alias Pleroma.Repo
  alias Pleroma.User

  use GenServer

  def start_link(_) do
    GenServer.start_link(
      __MODULE__,
      nil,
      name: __MODULE__
    )
  end

  @doc "Performs update stats"
  def force_update do
    GenServer.call(__MODULE__, :force_update)
  end

  @doc "Performs collect stats"
  def do_collect do
    GenServer.cast(__MODULE__, :run_update)
  end

  @doc "Returns stats data"
  @spec get_stats() :: %{domain_count: integer(), status_count: integer(), user_count: integer()}
  def get_stats do
    %{stats: stats} = GenServer.call(__MODULE__, :get_state)

    stats
  end

  @doc "Returns list peers"
  @spec get_peers() :: list(String.t())
  def get_peers do
    %{peers: peers} = GenServer.call(__MODULE__, :get_state)

    peers
  end

  def init(_args) do
    {:ok, calculate_stat_data()}
  end

  def handle_call(:force_update, _from, _state) do
    new_stats = calculate_stat_data()
    {:reply, new_stats, new_stats}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_cast(:run_update, _state) do
    new_stats = calculate_stat_data()

    {:noreply, new_stats}
  end

  def calculate_stat_data do
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

    users_query =
      from(u in User,
        where: u.deactivated != true,
        where: u.local == true,
        where: not is_nil(u.nickname),
        where: not u.invisible
      )

    user_count = Repo.aggregate(users_query, :count, :id)

    %{
      peers: peers,
      stats: %{
        domain_count: domain_count,
        status_count: status_count || 0,
        user_count: user_count
      }
    }
  end

  def get_status_visibility_count(instance \\ nil) do
    if is_nil(instance) do
      CounterCache.get_sum()
    else
      CounterCache.get_by_instance(instance)
    end
  end
end
