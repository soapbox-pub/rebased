# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Cron.AppCleanupWorker do
  @moduledoc """
  Cleans up registered apps that were never associated with a user.
  """

  use Oban.Worker, queue: "background"

  alias Pleroma.Web.OAuth.App

  @impl true
  def perform(_job) do
    App.remove_orphans()
  end

  @impl true
  def timeout(_job), do: :timer.seconds(30)
end
