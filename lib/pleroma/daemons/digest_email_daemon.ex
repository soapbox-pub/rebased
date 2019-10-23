# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Daemons.DigestEmailDaemon do
  alias Pleroma.Repo
  alias Pleroma.Workers.DigestEmailsWorker

  import Ecto.Query

  def perform do
    config = Pleroma.Config.get([:email_notifications, :digest])
    negative_interval = -Map.fetch!(config, :interval)
    inactivity_threshold = Map.fetch!(config, :inactivity_threshold)
    inactive_users_query = Pleroma.User.list_inactive_users_query(inactivity_threshold)

    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    from(u in inactive_users_query,
      where: fragment(~s(? ->'digest' @> 'true'), u.email_notifications),
      where: u.last_digest_emailed_at < datetime_add(^now, ^negative_interval, "day"),
      select: u
    )
    |> Repo.all()
    |> Enum.each(fn user ->
      DigestEmailsWorker.enqueue("digest_email", %{"user_id" => user.id})
    end)
  end

  @doc """
  Send digest email to the given user.
  Updates `last_digest_emailed_at` field for the user and returns the updated user.
  """
  @spec perform(Pleroma.User.t()) :: Pleroma.User.t()
  def perform(user) do
    with %Swoosh.Email{} = email <- Pleroma.Emails.UserEmail.digest_email(user) do
      Pleroma.Emails.Mailer.deliver_async(email)
    end

    Pleroma.User.touch_last_digest_emailed_at(user)
  end
end
