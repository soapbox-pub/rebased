# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.MailerWorker do
  use Pleroma.Workers.WorkerHelper, queue: "mailer"

  @impl Oban.Worker
  def perform(%{"op" => "email", "encoded_email" => encoded_email, "config" => config}, _job) do
    encoded_email
    |> Base.decode64!()
    |> :erlang.binary_to_term()
    |> Pleroma.Emails.Mailer.deliver(config)
  end
end
