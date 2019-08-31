# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.Token.CleanWorker do
  @moduledoc """
  The module represents functions to clean an expired oauth tokens.
  """
  use GenServer

  @ten_seconds 10_000
  @one_day 86_400_000

  @interval Pleroma.Config.get(
              [:oauth2, :clean_expired_tokens_interval],
              @one_day
            )

  alias Pleroma.Repo
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Workers.BackgroundWorker

  import Pleroma.Workers.WorkerHelper, only: [worker_args: 1]

  def start_link(_), do: GenServer.start_link(__MODULE__, %{})

  def init(_) do
    Process.send_after(self(), :perform, @ten_seconds)
    {:ok, nil}
  end

  @doc false
  def handle_info(:perform, state) do
    %{"op" => "clean_expired_tokens"}
    |> BackgroundWorker.new(worker_args(:background))
    |> Repo.insert()

    Process.send_after(self(), :perform, @interval)
    {:noreply, state}
  end

  def perform(:clean), do: Token.delete_expired_tokens()
end
