# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.Holder do
  @config Pleroma.Config.Loader.load_and_merge()

  @spec config() :: keyword()
  def config, do: @config

  @spec config(atom()) :: any()
  def config(group), do: @config[group]

  @spec config(atom(), atom()) :: any()
  def config(group, key), do: @config[group][key]
end
