# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Helpers.MediaHelper do
  @moduledoc """
  Handles common media-related operations.
  """

  def image_resize(url, %{max_width: max_width, max_height: max_height} = options) do
    quality = options[:quality] || 85

    cmd = ~s"""
    convert - -resize '#{max_width}x#{max_height}>' -quality #{quality} -
    """

    pid = Port.open({:spawn, cmd}, [:use_stdio, :in, :stream, :exit_status, :binary])
    {:ok, env} = url |> Pleroma.Web.MediaProxy.url() |> Pleroma.HTTP.get()
    image = env.body
    Port.command(pid, image)
    loop_recv(pid)
  end

  defp loop_recv(pid) do
    loop_recv(pid, <<>>)
  end

  defp loop_recv(pid, acc) do
    receive do
      {^pid, {:data, data}} ->
        loop_recv(pid, acc <> data)

      {^pid, {:exit_status, 0}} ->
        {:ok, acc}

      {^pid, {:exit_status, status}} ->
        {:error, status}
    end
  end
end
