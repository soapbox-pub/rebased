# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Stats do
  use GenServer

  import Ecto.Query

  alias Pleroma.CounterCache
  alias Pleroma.Repo
  alias Pleroma.User

  @interval :timer.seconds(60)

  def start_link(_) do
    GenServer.start_link(
      __MODULE__,
      nil,
      name: __MODULE__
    )
  end

  @impl true
  def init(_args) do
    if Pleroma.Config.get(:env) != :test do
      {:ok, nil, {:continue, :calculate_stats}}
    else
      {:ok, calculate_stat_data()}
    end
  end

  @doc "Performs update stats"
  def force_update do
    GenServer.call(__MODULE__, :force_update)
  end

  @doc "Returns stats data"
  @spec get_stats() :: %{
          domain_count: non_neg_integer(),
          status_count: non_neg_integer(),
          user_count: non_neg_integer()
        }
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

  @spec calculate_stat_data() :: %{
          peers: list(),
          stats: %{
            domain_count: non_neg_integer(),
            status_count: non_neg_integer(),
            user_count: non_neg_integer()
          }
        }
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
        where: u.is_active == true,
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

  @spec get_status_visibility_count(String.t() | nil) :: map()
  def get_status_visibility_count(instance \\ nil) do
    if is_nil(instance) do
      CounterCache.get_sum()
    else
      CounterCache.get_by_instance(instance)
    end
  end

  @impl true
  def handle_continue(:calculate_stats, _) do
    stats = calculate_stat_data()

    unless Pleroma.Config.get(:env) == :test do
      Process.send_after(self(), :run_update, @interval)
    end

    {:noreply, stats}
  end

  @impl true
  def handle_call(:force_update, _from, _state) do
    new_stats = calculate_stat_data()
    {:reply, new_stats, new_stats}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:run_update, _) do
    new_stats = calculate_stat_data()
    Process.send_after(self(), :run_update, @interval)
    {:noreply, new_stats}
  end
end
