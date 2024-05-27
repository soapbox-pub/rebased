# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.MailerWorker do
  use Pleroma.Workers.WorkerHelper, queue: "mailer"

  @impl Oban.Worker
  def perform(%Job{args: %{"op" => "email", "encoded_email" => encoded_email, "config" => config}}) do
    encoded_email
    |> Base.decode64!()
    |> :erlang.binary_to_term()
    |> Pleroma.Emails.Mailer.deliver(config)
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.seconds(5)
end
