# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Cron.NewUsersDigestWorker do
  alias Pleroma.Activity
  alias Pleroma.Repo
  alias Pleroma.User

  import Ecto.Query

  use Pleroma.Workers.WorkerHelper, queue: "new_users_digest"

  @impl Oban.Worker
  def perform(_args, _job) do
    if Pleroma.Config.get([Pleroma.Emails.NewUsersDigestEmail, :enabled]) do
      today = NaiveDateTime.utc_now() |> Timex.beginning_of_day()

      a_day_ago =
        today
        |> Timex.shift(days: -1)
        |> Timex.beginning_of_day()

      users_and_statuses =
        %{
          local: true,
          order_by: :inserted_at
        }
        |> User.Query.build()
        |> where([u], u.inserted_at >= ^a_day_ago and u.inserted_at < ^today)
        |> Repo.all()
        |> Enum.map(fn user ->
          latest_status =
            Activity
            |> Activity.Queries.by_actor(user.ap_id)
            |> Activity.Queries.by_type("Create")
            |> Activity.with_preloaded_object()
            |> order_by(desc: :inserted_at)
            |> limit(1)
            |> Repo.one()

          total_statuses =
            Activity
            |> Activity.Queries.by_actor(user.ap_id)
            |> Activity.Queries.by_type("Create")
            |> Repo.aggregate(:count, :id)

          {user, total_statuses, latest_status}
        end)

      if users_and_statuses != [] do
        %{is_admin: true}
        |> User.Query.build()
        |> Repo.all()
        |> Enum.map(&Pleroma.Emails.NewUsersDigestEmail.new_users(&1, users_and_statuses))
        |> Enum.each(&Pleroma.Emails.Mailer.deliver/1)
      end
    end
  end
end
