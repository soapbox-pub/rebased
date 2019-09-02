# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.DigestEmailsWorker do
  alias Pleroma.User

  use Pleroma.Workers.WorkerHelper, queue: "digest_emails"

  @impl Oban.Worker
  def perform(%{"op" => "digest_email", "user_id" => user_id}, _job) do
    user_id
    |> User.get_cached_by_id()
    |> Pleroma.Daemons.DigestEmailDaemon.perform()
  end
end
