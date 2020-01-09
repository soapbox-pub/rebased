# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Stats do
  import Ecto.Query
  alias Pleroma.CounterCache
  alias Pleroma.Repo
  alias Pleroma.User

  use GenServer

  @init_state %{
    peers: [],
    stats: %{
      domain_count: 0,
      status_count: 0,
      user_count: 0
    }
  }

  def start_link(_) do
    GenServer.start_link(
      __MODULE__,
      @init_state,
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

  def init(args) do
    {:ok, args}
  end

  def handle_call(:force_update, _from, _state) do
    new_stats = get_stat_data()
    {:reply, new_stats, new_stats}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_cast(:run_update, _state) do
    new_stats = get_stat_data()

    {:noreply, new_stats}
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
      stats: %{
        domain_count: domain_count,
        status_count: status_count,
        user_count: user_count
      }
    }
  end

  def get_status_visibility_count do
    counter_cache =
      CounterCache.get_as_map([
        "status_visibility_public",
        "status_visibility_private",
        "status_visibility_unlisted",
        "status_visibility_direct"
      ])

    %{
      public: counter_cache["status_visibility_public"] || 0,
      unlisted: counter_cache["status_visibility_unlisted"] || 0,
      private: counter_cache["status_visibility_private"] || 0,
      direct: counter_cache["status_visibility_direct"] || 0
    }
  end
end
