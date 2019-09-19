# Pleroma: A lightweight social networking server
# Copyright © 2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Daemons.ActivityExpirationDaemon do
  alias Pleroma.Activity
  alias Pleroma.ActivityExpiration
  alias Pleroma.Config
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  require Logger
  use GenServer
  import Ecto.Query

  @schedule_interval :timer.minutes(1)

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  @impl true
  def init(_) do
    if Config.get([ActivityExpiration, :enabled]) do
      schedule_next()
      {:ok, nil}
    else
      :ignore
    end
  end

  def perform(:execute, expiration_id) do
    try do
      expiration =
        ActivityExpiration
        |> where([e], e.id == ^expiration_id)
        |> Repo.one!()

      activity = Activity.get_by_id_with_object(expiration.activity_id)
      user = User.get_by_ap_id(activity.object.data["actor"])
      CommonAPI.delete(activity.id, user)
    rescue
      error ->
        Logger.error("#{__MODULE__} Couldn't delete expired activity: #{inspect(error)}")
    end
  end

  @impl true
  def handle_info(:perform, state) do
    ActivityExpiration.due_expirations(@schedule_interval)
    |> Enum.each(fn expiration ->
      Pleroma.Workers.ActivityExpirationWorker.enqueue(
        "activity_expiration",
        %{"activity_expiration_id" => expiration.id}
      )
    end)

    schedule_next()
    {:noreply, state}
  end

  defp schedule_next do
    Process.send_after(self(), :perform, @schedule_interval)
  end
end
