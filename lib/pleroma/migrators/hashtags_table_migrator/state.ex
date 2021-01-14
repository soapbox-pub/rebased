defmodule Pleroma.Migrators.HashtagsTableMigrator.State do
  use Agent

  @init_state %{}

  def start_link(_) do
    Agent.start_link(fn -> @init_state end, name: __MODULE__)
  end

  def get do
    Agent.get(__MODULE__, & &1)
  end

  def put(key, value) do
    Agent.update(__MODULE__, fn state ->
      Map.put(state, key, value)
    end)
  end

  def increment(key, increment \\ 1) do
    Agent.update(__MODULE__, fn state ->
      updated_value = (state[key] || 0) + increment
      Map.put(state, key, updated_value)
    end)
  end
end
