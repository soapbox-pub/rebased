# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.TransmogrifierWorker do
  alias Pleroma.User

  # Note: `max_attempts` is intended to be overridden in `new/2` call
  use Oban.Worker,
    queue: "transmogrifier",
    max_attempts: 1

  @impl Oban.Worker
  def perform(%{"op" => "user_upgrade", "user_id" => user_id}, _job) do
    user = User.get_cached_by_id(user_id)
    Pleroma.Web.ActivityPub.Transmogrifier.perform(:user_upgrade, user)
  end
end
