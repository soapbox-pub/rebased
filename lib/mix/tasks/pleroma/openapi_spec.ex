# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.OpenapiSpec do
  def run([path]) do
    # Load Pleroma application to get version info
    Application.load(:pleroma)
    spec = Pleroma.Web.ApiSpec.spec(server_specific: false) |> Jason.encode!()
    File.write(path, spec)
  end
end
