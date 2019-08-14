# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Mailer do
  alias Pleroma.User

  # Note: `max_attempts` is intended to be overridden in `new/1` call
  use Oban.Worker,
    queue: "mailer",
    max_attempts: Pleroma.Config.get([:workers, :retries, :compile_time_default])

  @impl Oban.Worker
  def perform(%{"op" => "email", "encoded_email" => encoded_email, "config" => config}) do
    email =
      encoded_email
      |> Base.decode64!()
      |> :erlang.binary_to_term()

    Pleroma.Emails.Mailer.deliver(email, config)
  end

  def perform(%{"op" => "digest_email", "user_id" => user_id}) do
    user = User.get_by_id(user_id)
    Pleroma.DigestEmailWorker.perform(user)
  end
end
