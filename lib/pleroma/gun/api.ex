# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Gun.API do
  @callback open(charlist(), pos_integer(), map()) :: {:ok, pid()}
  @callback info(pid()) :: map()
  @callback close(pid()) :: :ok
  @callback await_up(pid) :: {:ok, atom()} | {:error, atom()}
  @callback connect(pid(), map()) :: reference()
  @callback await(pid(), reference()) :: {:response, :fin, 200, []}

  def open(host, port, opts), do: api().open(host, port, opts)

  def info(pid), do: api().info(pid)

  def close(pid), do: api().close(pid)

  def await_up(pid), do: api().await_up(pid)

  def connect(pid, opts), do: api().connect(pid, opts)

  def await(pid, ref), do: api().await(pid, ref)

  defp api, do: Pleroma.Config.get([Pleroma.Gun.API], Pleroma.Gun)
end
