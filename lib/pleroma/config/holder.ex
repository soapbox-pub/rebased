# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.Holder do
  @config Pleroma.Config.Loader.default_config()

  @spec to_ets() :: true
  def to_ets do
    :ets.new(:default_config, [:named_table, :protected])

    default_config =
      if System.get_env("RELEASE_NAME") do
        release_config =
          [:code.root_dir(), "releases", System.get_env("RELEASE_VSN"), "releases.exs"]
          |> Path.join()
          |> Pleroma.Config.Loader.read()

        Pleroma.Config.Loader.merge(@config, release_config)
      else
        @config
      end

    :ets.insert(:default_config, {:config, default_config})
  end

  @spec default_config() :: keyword()
  def default_config, do: from_ets()

  @spec default_config(atom()) :: keyword()
  def default_config(group), do: Keyword.get(from_ets(), group)

  @spec default_config(atom(), atom()) :: keyword()
  def default_config(group, key), do: get_in(from_ets(), [group, key])

  defp from_ets do
    [{:config, default_config}] = :ets.lookup(:default_config, :config)
    default_config
  end
end
