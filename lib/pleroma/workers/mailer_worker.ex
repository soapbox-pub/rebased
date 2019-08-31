# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.MailerWorker do
  alias Pleroma.User

  # Note: `max_attempts` is intended to be overridden in `new/2` call
  use Oban.Worker,
    queue: "mailer",
    max_attempts: 1

  @impl Oban.Worker
  def perform(%{"op" => "email", "encoded_email" => encoded_email, "config" => config}, _job) do
    encoded_email
    |> Base.decode64!()
    |> :erlang.binary_to_term()
    |> Pleroma.Emails.Mailer.deliver(config)
  end

  def perform(%{"op" => "digest_email", "user_id" => user_id}, _job) do
    user_id
    |> User.get_cached_by_id()
    |> Pleroma.DigestEmailWorker.perform()
  end
end
