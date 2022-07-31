# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.PurgeExpiredActivity do
  @moduledoc """
  Worker which purges expired activity.
  """

  use Oban.Worker, queue: :activity_expiration, max_attempts: 1, unique: [period: :infinity]

  import Ecto.Query

  alias Pleroma.Activity

  @spec enqueue(map()) ::
          {:ok, Oban.Job.t()}
          | {:error, :expired_activities_disabled}
          | {:error, :expiration_too_close}
  def enqueue(args) do
    with true <- enabled?() do
      {scheduled_at, args} = Map.pop(args, :expires_at)

      args
      |> new(scheduled_at: scheduled_at)
      |> Oban.insert()
    end
  end

  @impl true
  def perform(%Oban.Job{args: %{"activity_id" => id}}) do
    with %Activity{} = activity <- find_activity(id),
         %Pleroma.User{} = user <- find_user(activity.object.data["actor"]) do
      Pleroma.Web.CommonAPI.delete(activity.id, user)
    end
  end

  defp enabled? do
    with false <- Pleroma.Config.get([__MODULE__, :enabled], false) do
      {:error, :expired_activities_disabled}
    end
  end

  defp find_activity(id) do
    with nil <- Activity.get_by_id_with_object(id) do
      {:error, :activity_not_found}
    end
  end

  defp find_user(ap_id) do
    with nil <- Pleroma.User.get_by_ap_id(ap_id) do
      {:error, :user_not_found}
    end
  end

  def get_expiration(id) do
    from(j in Oban.Job,
      where: j.state == "scheduled",
      where: j.queue == "activity_expiration",
      where: fragment("?->>'activity_id' = ?", j.args, ^id)
    )
    |> Pleroma.Repo.one()
  end

  @spec expires_late_enough?(DateTime.t()) :: boolean()
  def expires_late_enough?(scheduled_at) do
    now = DateTime.utc_now()
    diff = DateTime.diff(scheduled_at, now, :millisecond)
    min_lifetime = Pleroma.Config.get([__MODULE__, :min_lifetime], 600)
    diff > :timer.seconds(min_lifetime)
  end
end
