# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Frontend do
  use Mix.Task

  import Mix.Pleroma

  @shortdoc "Manages bundled Pleroma frontends"

  @moduledoc File.read!("docs/administration/CLI_tasks/frontend.md")

  def run(["install", "none" | _args]) do
    shell_info("Skipping frontend installation because none was requested")
    "none"
  end

  def run(["install", frontend | args]) do
    start_pleroma()

    {options, [], []} =
      OptionParser.parse(
        args,
        strict: [
          ref: :string,
          static_dir: :string,
          build_url: :string,
          build_dir: :string,
          file: :string
        ]
      )

    Pleroma.Frontend.install(frontend, options)
  end
end
