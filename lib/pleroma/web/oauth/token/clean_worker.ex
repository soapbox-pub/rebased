# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.Token.CleanWorker do
  @moduledoc """
  The module represents functions to clean an expired oauth tokens.
  """
  use GenServer

  @ten_seconds 10_000
  @one_day 86_400_000

  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Workers.BackgroundWorker

  def start_link(_), do: GenServer.start_link(__MODULE__, %{})

  def init(_) do
    Process.send_after(self(), :perform, @ten_seconds)
    {:ok, nil}
  end

  @doc false
  def handle_info(:perform, state) do
    BackgroundWorker.enqueue("clean_expired_tokens", %{})
    interval = Pleroma.Config.get([:oauth2, :clean_expired_tokens_interval], @one_day)

    Process.send_after(self(), :perform, interval)
    {:noreply, state}
  end

  def perform(:clean), do: Token.delete_expired_tokens()
end
