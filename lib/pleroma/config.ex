defmodule Pleroma.Config do
  use Agent

  def start_link(initial) do
    Agent.start_link(fn -> initial end, name: __MODULE__)
  end

  def get(path) do
    Agent.get(__MODULE__, Kernel, :get_in, [path])
  end

  def put(path, value) do
    Agent.update(__MODULE__, Kernel, :put_in, [path, value])
  end
end
