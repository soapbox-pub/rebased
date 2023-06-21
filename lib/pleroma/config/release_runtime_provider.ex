# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.ReleaseRuntimeProvider do
  @moduledoc """
  Imports runtime config and `{env}.exported_from_db.secret.exs` for releases.
  """
  @behaviour Config.Provider

  @impl true
  def init(opts), do: opts

  @impl true
  def load(config, opts) do
    with_defaults = Config.Reader.merge(config, Pleroma.Config.Holder.release_defaults())

    config_path =
      opts[:config_path] || System.get_env("PLEROMA_CONFIG_PATH") || "/etc/pleroma/config.exs"

    with_runtime_config =
      if File.exists?(config_path) do
        # <https://git.pleroma.social/pleroma/pleroma/-/issues/3135>
        %File.Stat{mode: mode} = File.lstat!(config_path)

        if Bitwise.band(mode, 0o007) > 0 do
          raise "Configuration at #{config_path} has world-permissions, execute the following: chmod o= #{config_path}"
        end

        if Bitwise.band(mode, 0o020) > 0 do
          raise "Configuration at #{config_path} has group-wise write permissions, execute the following: chmod g-w #{config_path}"
        end

        # Note: Elixir doesn't provides a getuid(2)
        # so cannot forbid group-read only when config is owned by us

        runtime_config = Config.Reader.read!(config_path)

        with_defaults
        |> Config.Reader.merge(pleroma: [config_path: config_path])
        |> Config.Reader.merge(runtime_config)
      else
        warning = [
          IO.ANSI.red(),
          IO.ANSI.bright(),
          "!!! Config path is not declared! Please ensure it exists and that PLEROMA_CONFIG_PATH is unset or points to an existing file",
          IO.ANSI.reset()
        ]

        IO.puts(warning)
        with_defaults
      end

    exported_config_path =
      opts[:exported_config_path] ||
        config_path
        |> Path.dirname()
        |> Path.join("#{Pleroma.Config.get(:env)}.exported_from_db.secret.exs")

    with_exported =
      if File.exists?(exported_config_path) do
        exported_config = Config.Reader.read!(exported_config_path)
        Config.Reader.merge(with_runtime_config, exported_config)
      else
        with_runtime_config
      end

    with_exported
  end
end
