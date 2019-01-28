# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Jobs.WorkerMock do
  require Logger

  def perform(:test_job, arg, arg2) do
    Logger.debug({:perform, :test_job, arg, arg2})
  end

  def perform(:test_job, payload) do
    Logger.debug({:perform, :test_job, payload})
  end

  def test_job(payload) do
    Pleroma.Jobs.enqueue(:testing, __MODULE__, [:test_job, payload])
  end
end
