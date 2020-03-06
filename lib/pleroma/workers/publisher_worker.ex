# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.PublisherWorker do
  alias Pleroma.Activity
  alias Pleroma.Web.Federator

  use Pleroma.Workers.WorkerHelper, queue: "federator_outgoing"

  def backoff(attempt) when is_integer(attempt) do
    Pleroma.Workers.WorkerHelper.sidekiq_backoff(attempt, 5)
  end

  @impl Oban.Worker
  def perform(%{"op" => "publish", "activity_id" => activity_id}, _job) do
    activity = Activity.get_by_id(activity_id)
    Federator.perform(:publish, activity)
  end

  def perform(%{"op" => "publish_one", "module" => module_name, "params" => params}, _job) do
    params = Map.new(params, fn {k, v} -> {String.to_atom(k), v} end)
    Federator.perform(:publish_one, String.to_atom(module_name), params)
  end
end
