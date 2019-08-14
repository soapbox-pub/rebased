# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Stats do
  import Ecto.Query
  alias Pleroma.Repo
  alias Pleroma.User

  use Agent

  def start_link(_) do
    agent = Agent.start_link(fn -> {[], %{}} end, name: __MODULE__)
    spawn(fn -> schedule_update() end)
    agent
  end

  def get_stats do
    Agent.get(__MODULE__, fn {_, stats} -> stats end)
  end

  def get_peers do
    Agent.get(__MODULE__, fn {peers, _} -> peers end)
  end

  def schedule_update do
    spawn(fn ->
      # 1 hour
      Process.sleep(1000 * 60 * 60)
      schedule_update()
    end)

    update_stats()
  end

  def update_stats do
    peers =
      from(
        u in User,
        select: fragment("distinct split_part(?, '@', 2)", u.nickname),
        where: u.local != ^true
      )
      |> Repo.all()
      |> Enum.filter(& &1)

    domain_count = Enum.count(peers)

    status_query =
      from(u in User.Query.build(%{local: true}),
        select: fragment("sum((?->>'note_count')::int)", u.info)
      )

    status_count = Repo.one(status_query)

    user_count = Repo.aggregate(User.Query.build(%{local: true, active: true}), :count, :id)

    Agent.update(__MODULE__, fn _ ->
      {peers, %{domain_count: domain_count, status_count: status_count, user_count: user_count}}
    end)
  end
end
