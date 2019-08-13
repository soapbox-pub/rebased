# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Helper do
  def worker_args(queue) do
    if max_attempts = Pleroma.Config.get([:workers, :retries, queue]) do
      [max_attempts: max_attempts]
    else
      []
    end
  end
end
