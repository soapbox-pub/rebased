# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.ReleaseEnv do
  use Mix.Task
  import Mix.Pleroma

  @shortdoc "Generate Pleroma environment file."
  @moduledoc File.read!("docs/administration/CLI_tasks/release_environments.md")

  def run(["gen" | rest]) do
    {options, [], []} =
      OptionParser.parse(
        rest,
        strict: [
          force: :boolean,
          path: :string
        ],
        aliases: [
          p: :path,
          f: :force
        ]
      )

    env_path =
      get_option(
        options,
        :path,
        "Environment file path",
        "config/pleroma.env"
      )
      |> Path.expand()

    proceed? =
      if File.exists?(env_path) do
        get_option(
          options,
          :force,
          "Environment file is exist. Do you want overwritten the #{env_path} file? (y/n)",
          "n"
        ) === "y"
      else
        true
      end

    if proceed? do
      do_generate(env_path)

      shell_info(
        "The file generated: #{env_path}.\nTo use the enviroment file need to add the line ';EnvironmentFile=#{
          env_path
        }' in service file (/installation/pleroma.service)."
      )
    end
  end

  def do_generate(path) do
    content = "RELEASE_COOKIE=#{Base.encode32(:crypto.strong_rand_bytes(32))}"

    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end
end
