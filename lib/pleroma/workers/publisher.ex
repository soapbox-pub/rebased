# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Publisher do
  alias Pleroma.Activity
  alias Pleroma.Web.Federator

  # Note: `max_attempts` is intended to be overridden in `new/1` call
  use Oban.Worker,
    queue: "federator_outgoing",
    max_attempts: 1

  @impl Oban.Worker
  def perform(%{"op" => "publish", "activity_id" => activity_id}, _job) do
    activity = Activity.get_by_id(activity_id)
    Federator.perform(:publish, activity)
  end

  def perform(%{"op" => "publish_one", "module" => module_name, "params" => params}, _job) do
    Federator.perform(:publish_one, String.to_atom(module_name), params)
  end
end
