# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Streamer do
  alias Pleroma.Web.Streamer.State
  alias Pleroma.Web.Streamer.Worker

  @timeout 60_000
  @mix_env Mix.env()

  def add_socket(topic, socket) do
    State.add_socket(topic, socket)
  end

  def remove_socket(topic, socket) do
    State.remove_socket(topic, socket)
  end

  def get_sockets do
    State.get_sockets()
  end

  def stream(topics, items) do
    if should_send?() do
      Task.async(fn ->
        :poolboy.transaction(
          :streamer_worker,
          &Worker.stream(&1, topics, items),
          @timeout
        )
      end)
    end
  end

  def supervisor, do: Pleroma.Web.Streamer.Supervisor

  defp should_send? do
    handle_should_send(@mix_env)
  end

  defp handle_should_send(:test) do
    case Process.whereis(:streamer_worker) do
      nil ->
        false

      pid ->
        Process.alive?(pid)
    end
  end

  defp handle_should_send(:benchmark), do: false

  defp handle_should_send(_), do: true
end
