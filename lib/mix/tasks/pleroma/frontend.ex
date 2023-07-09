# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Frontend do
  use Mix.Task

  import Mix.Pleroma

  alias Pleroma.Frontend

  @shortdoc "Manages bundled Pleroma frontends"

  @moduledoc File.read!("docs/administration/CLI_tasks/frontend.md")

  def run(["install", "none" | _args]) do
    shell_info("Skipping frontend installation because none was requested")
    "none"
  end

  def run(["install", name | args]) do
    start_pleroma()

    {options, [], []} =
      OptionParser.parse(
        args,
        strict: [
          ref: :string,
          build_url: :string,
          build_dir: :string,
          file: :string,
          admin: :boolean,
          primary: :boolean
        ]
      )

    shell_info("Installing frontend #{name}...")

    with %Frontend{} = fe <-
           options
           |> Keyword.put(:name, name)
           |> opts_to_frontend()
           |> Frontend.install() do
      shell_info("Frontend #{fe.name} installed")

      if get_frontend_type(options) do
        run(["enable", name] ++ args)
      end
    else
      error ->
        shell_error("Failed to install frontend")
        exit(inspect(error))
    end
  end

  def run(["enable", name | args]) do
    start_pleroma()

    {options, [], []} =
      OptionParser.parse(
        args,
        strict: [
          ref: :string,
          build_url: :string,
          build_dir: :string,
          file: :string,
          admin: :boolean,
          primary: :boolean
        ]
      )

    frontend_type = get_frontend_type(options) || :primary

    shell_info("Enabling frontend #{name}...")

    with %Frontend{} = fe <-
           options
           |> Keyword.put(:name, name)
           |> opts_to_frontend()
           |> Frontend.enable(frontend_type) do
      shell_info("Frontend #{fe.name} enabled")
    else
      error ->
        shell_error("Failed to enable frontend")
        exit(inspect(error))
    end
  end

  defp opts_to_frontend(opts) do
    struct(Frontend, opts)
  end

  defp get_frontend_type(opts) do
    case Enum.into(opts, %{}) do
      %{admin: true, primary: true} ->
        raise "Invalid command. Only one frontend type may be selected."

      %{admin: true} ->
        :admin

      %{primary: true} ->
        :primary

      _ ->
        nil
    end
  end
end
