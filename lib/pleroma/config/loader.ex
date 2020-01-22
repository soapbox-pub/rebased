# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.Loader do
  @paths ["config/config.exs", "config/#{Mix.env()}.exs"]

  @reject_keys [
    Pleroma.Repo,
    Pleroma.Web.Endpoint,
    :env,
    :configurable_from_database,
    :database,
    :swarm
  ]

  if Code.ensure_loaded?(Config.Reader) do
    @spec load(Path.t()) :: keyword()
    def load(path), do: Config.Reader.read!(path)

    defp do_merge(conf1, conf2), do: Config.Reader.merge(conf1, conf2)
  else
    # support for Elixir less than 1.9
    @spec load(Path.t()) :: keyword()
    def load(path) do
      path
      |> Mix.Config.eval!()
      |> elem(0)
    end

    defp do_merge(conf1, conf2), do: Mix.Config.merge(conf1, conf2)
  end

  @spec load_and_merge() :: keyword()
  def load_and_merge do
    all_paths =
      if Pleroma.Config.get(:release),
        do: @paths ++ ["config/releases.exs"],
        else: @paths

    all_paths
    |> Enum.map(&load(&1))
    |> Enum.reduce([], &do_merge(&2, &1))
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
