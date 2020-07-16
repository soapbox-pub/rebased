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

    file_path =
      get_option(
        options,
        :path,
        "Environment file path",
        "./config/pleroma.env"
      )

    env_path = Path.expand(file_path)

    proceed? =
      if File.exists?(env_path) do
        get_option(
          options,
          :force,
          "Environment file already exists. Do you want to overwrite the #{env_path} file? (y/n)",
          "n"
        ) === "y"
      else
        true
      end

    if proceed? do
      case do_generate(env_path) do
        {:error, reason} ->
          shell_error(
            File.Error.message(%{action: "write to file", reason: reason, path: env_path})
          )

        _ ->
          shell_info("\nThe file generated: #{env_path}.\n")

          shell_info("""
          WARNING: before start pleroma app please make sure to make the file read-only and non-modifiable.
            Example:
              chmod 0444 #{file_path}
              chattr +i #{file_path}
          """)
      end
    else
      shell_info("\nThe file is exist. #{env_path}.\n")
    end
  end

  def do_generate(path) do
    content = "RELEASE_COOKIE=#{Base.encode32(:crypto.strong_rand_bytes(32))}"

    File.mkdir_p!(Path.dirname(path))
    File.write(path, content)
  end
end
