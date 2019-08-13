# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.Token.CleanWorker do
  @moduledoc """
  The module represents functions to clean an expired oauth tokens.
  """

  # 10 seconds
  @start_interval 10_000
  @interval Pleroma.Config.get(
              # 24 hours
              [:oauth2, :clean_expired_tokens_interval],
              86_400_000
            )

  alias Pleroma.Repo
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Workers.BackgroundWorker

  defdelegate worker_args(queue), to: Pleroma.Workers.Helper

  def start_link, do: GenServer.start_link(__MODULE__, nil)

  def init(_) do
    if Pleroma.Config.get([:oauth2, :clean_expired_tokens], false) do
      Process.send_after(self(), :perform, @start_interval)
      {:ok, nil}
    else
      :ignore
    end
  end

  @doc false
  def handle_info(:perform, state) do
    %{"op" => "clean_expired_tokens"}
    |> BackgroundWorker.new(worker_args(:background))
    |> Repo.insert()

    Process.send_after(self(), :perform, @interval)
    {:noreply, state}
  end

  # Job Worker Callbacks
  def perform(:clean), do: Token.delete_expired_tokens()
end
