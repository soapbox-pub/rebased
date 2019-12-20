# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Stats do
  use GenServer

  import Ecto.Query

  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User

  require Pleroma.Constants

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

  def get_stat_data do
    peers =
      from(
        u in User,
        select: fragment("distinct split_part(?, '@', 2)", u.nickname),
        where: u.local != ^true
      )
      |> Repo.all()
      |> Enum.filter(& &1)

    domain_count = Enum.count(peers)

    user_count = Repo.aggregate(User.Query.build(%{local: true, active: true}), :count, :id)

    %{
      peers: peers,
      stats: %{domain_count: domain_count, status_count: status_count(), user_count: user_count}
    }
  end

  defp status_count do
    %{
      all: all_statuses_query() |> Repo.aggregate(:count, :id),
      public: public_statuses_query() |> Repo.aggregate(:count, :id),
      unlisted: unlisted_statuses_query() |> Repo.aggregate(:count, :id),
      direct: direct_statuses_query() |> Repo.aggregate(:count, :id),
      private: private_statuses_query() |> Repo.aggregate(:count, :id)
    }
  end

  defp all_statuses_query do
    from(o in Object, where: fragment("(?)->>'type' = 'Note'", o.data))
  end

  def public_statuses_query do
    from(o in Object,
      where: fragment("(?)->'to' \\? ?", o.data, ^Pleroma.Constants.as_public())
    )
  end

  def unlisted_statuses_query do
    from(o in Object,
      where: not fragment("(?)->'to' \\? ?", o.data, ^Pleroma.Constants.as_public()),
      where: fragment("(?)->'cc' \\? ?", o.data, ^Pleroma.Constants.as_public())
    )
  end

  def direct_statuses_query do
    private_statuses_ids = from(p in private_statuses_query(), select: p.id) |> Repo.all()

    from(o in Object,
      where:
        fragment(
          "? \\? 'directMessage' AND (?->>'directMessage')::boolean = true",
          o.data,
          o.data
        ) or
          (not fragment("(?)->'to' \\? ?", o.data, ^Pleroma.Constants.as_public()) and
             not fragment("(?)->'cc' \\? ?", o.data, ^Pleroma.Constants.as_public()) and
             o.id not in ^private_statuses_ids)
    )
  end

  def private_statuses_query do
    from(o in subquery(recipients_query()),
      where: ilike(o.recipients, "%/followers%")
    )
  end

  defp recipients_query do
    from(o in Object,
      select: %{
        id: o.id,
        recipients: fragment("jsonb_array_elements_text((?)->'to')", o.data)
      },
      where: not fragment("(?)->'to' \\? ?", o.data, ^Pleroma.Constants.as_public()),
      where: not fragment("(?)->'cc' \\? ?", o.data, ^Pleroma.Constants.as_public())
    )
  end
end
