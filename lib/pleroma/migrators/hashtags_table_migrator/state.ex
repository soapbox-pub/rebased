# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Migrators.HashtagsTableMigrator.State do
  use Agent

  @init_state %{}
  @reg_name {:global, __MODULE__}

  def start_link(_) do
    Agent.start_link(fn -> @init_state end, name: @reg_name)
  end

  def get do
    Agent.get(@reg_name, & &1)
  end

  def put(key, value) do
    Agent.update(@reg_name, fn state ->
      Map.put(state, key, value)
    end)
  end

  def increment(key, increment \\ 1) do
    Agent.update(@reg_name, fn state ->
      updated_value = (state[key] || 0) + increment
      Map.put(state, key, updated_value)
    end)
  end
end
