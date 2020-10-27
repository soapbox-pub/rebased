# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.FrontendInstallerWorker do
  use Oban.Worker, queue: :frontend_installer, max_attempts: 1

  alias Oban.Job
  alias Pleroma.Frontend

  def install(name, opts \\ []) do
    %{"name" => name, "opts" => Map.new(opts)}
    |> new()
    |> Oban.insert()
  end

  def perform(%Job{args: %{"name" => name, "opts" => opts}}) do
    opts = Keyword.new(opts, fn {key, value} -> {String.to_existing_atom(key), value} end)
    Frontend.install(name, opts)
  end
end
