# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Common do
  @doc "Common functions to be reused in mix tasks"
  def start_pleroma do
    Application.put_env(:phoenix, :serve_endpoints, false, persistent: true)
    {:ok, _} = Application.ensure_all_started(:pleroma)
  end

  def get_option(options, opt, prompt, defval \\ nil, defname \\ nil) do
    Keyword.get(options, opt) ||
      case Mix.shell().prompt("#{prompt} [#{defname || defval}]") do
        "\n" ->
          case defval do
            nil -> get_option(options, opt, prompt, defval)
            defval -> defval
          end

        opt ->
          opt |> String.trim()
      end
  end

  def escape_sh_path(path) do
    ~S(') <> String.replace(path, ~S('), ~S(\')) <> ~S(')
  end
end
