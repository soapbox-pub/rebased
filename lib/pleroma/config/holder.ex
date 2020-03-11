# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.Holder do
  @config Pleroma.Config.Loader.default_config()

  @spec save_default() :: :ok
  def save_default do
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

    Pleroma.Config.put(:default_config, default_config)
  end

  @spec default_config() :: keyword()
  def default_config, do: get_default()

  @spec default_config(atom()) :: keyword()
  def default_config(group), do: Keyword.get(get_default(), group)

  @spec default_config(atom(), atom()) :: keyword()
  def default_config(group, key), do: get_in(get_default(), [group, key])

  defp get_default, do: Pleroma.Config.get(:default_config)
end
