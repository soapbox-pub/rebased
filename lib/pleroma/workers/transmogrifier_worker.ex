# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.TransmogrifierWorker do
  alias Pleroma.User

  use Pleroma.Workers.WorkerHelper, queue: "transmogrifier"

  @impl Oban.Worker
  def perform(%Job{args: %{"op" => "user_upgrade", "user_id" => user_id}}) do
    user = User.get_cached_by_id(user_id)
    Pleroma.Web.ActivityPub.Transmogrifier.perform(:user_upgrade, user)
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.seconds(5)
end
