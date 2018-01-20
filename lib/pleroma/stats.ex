defmodule Pleroma.Stats do
  use Agent
  import Ecto.Query
  alias Pleroma.{User, Repo, Activity}

  def start_link do
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
      Process.sleep(1000 * 60 * 60 * 1) # 1 hour
      schedule_update()
    end)
    update_stats()
  end

  def update_stats do
    peers = from(u in Pleroma.User,
      select: fragment("distinct ?->'host'", u.info),
      where: u.local != ^true)
    |> Repo.all()
    domain_count = Enum.count(peers)
    status_query = from(u in User.local_user_query,
      select: fragment("sum((?->>'note_count')::int)", u.info))
    status_count = Repo.one(status_query) |> IO.inspect
    user_count = Repo.aggregate(User.local_user_query, :count, :id)
    Agent.update(__MODULE__, fn _ ->
      {peers, %{domain_count: domain_count, status_count: status_count, user_count: user_count}}
    end)
  end
end
