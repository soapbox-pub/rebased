# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Cron.DigestEmailsWorker do
  @moduledoc """
  The worker to send digest emails.
  """

  use Oban.Worker, queue: "digest_emails"

  alias Pleroma.Config
  alias Pleroma.Emails
  alias Pleroma.Repo
  alias Pleroma.User

  import Ecto.Query

  require Logger

  @impl Oban.Worker
  def perform(_opts, _job) do
    config = Config.get([:email_notifications, :digest])

    if config[:active] do
      negative_interval = -Map.fetch!(config, :interval)
      inactivity_threshold = Map.fetch!(config, :inactivity_threshold)
      inactive_users_query = User.list_inactive_users_query(inactivity_threshold)

      now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

      from(u in inactive_users_query,
        where: fragment(~s(? ->'digest' @> 'true'), u.email_notifications),
        where: not is_nil(u.email),
        where: u.last_digest_emailed_at < datetime_add(^now, ^negative_interval, "day"),
        select: u
      )
      |> Repo.all()
      |> send_emails
    end
  end

  def send_emails(users) do
    Enum.each(users, &send_email/1)
  end

  @doc """
  Send digest email to the given user.
  Updates `last_digest_emailed_at` field for the user and returns the updated user.
  """
  @spec send_email(User.t()) :: User.t()
  def send_email(user) do
    with %Swoosh.Email{} = email <- Emails.UserEmail.digest_email(user) do
      Emails.Mailer.deliver_async(email)
    end

    User.touch_last_digest_emailed_at(user)
  end
end
