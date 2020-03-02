# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.RobotsTxt do
  use Mix.Task

  @shortdoc "Generate robots.txt"
  @moduledoc """
  Generates robots.txt

  ## Overwrite robots.txt to disallow all

      mix pleroma.robots_txt disallow_all

  This will write a robots.txt that will hide all paths on your instance
  from search engines and other robots that obey robots.txt

  """
  def run(["disallow_all"]) do
    Mix.Pleroma.start_pleroma()
    static_dir = Pleroma.Config.get([:instance, :static_dir], "instance/static/")

    if !File.exists?(static_dir) do
      File.mkdir_p!(static_dir)
    end

    robots_txt_path = Path.join(static_dir, "robots.txt")
    robots_txt_content = "User-Agent: *\nDisallow: /\n"

    File.write!(robots_txt_path, robots_txt_content, [:write])
  end
end
