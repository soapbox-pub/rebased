# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.Loader do
  @reject_keys [
    Pleroma.Repo,
    Pleroma.Web.Endpoint,
    :env,
    :configurable_from_database,
    :database,
    :swarm
  ]

  if Code.ensure_loaded?(Config.Reader) do
    @reader Config.Reader

    def read(path), do: @reader.read!(path)
  else
    # support for Elixir less than 1.9
    @reader Mix.Config
    def read(path) do
      path
      |> @reader.eval!()
      |> elem(0)
    end
  end

  @spec read(Path.t()) :: keyword()

  @spec merge(keyword(), keyword()) :: keyword()
  def merge(c1, c2), do: @reader.merge(c1, c2)

  @spec default_config() :: keyword()
  def default_config do
    "config/config.exs"
    |> read()
    |> filter()
  end

  defp filter(configs) do
    configs
    |> Keyword.keys()
    |> Enum.reduce([], &Keyword.put(&2, &1, filter_group(&1, configs)))
  end

  @spec filter_group(atom(), keyword()) :: keyword()
  def filter_group(group, configs) do
    Enum.reject(configs[group], fn {key, _v} ->
      key in @reject_keys or (group == :phoenix and key == :serve_endpoints)
    end)
  end
end
