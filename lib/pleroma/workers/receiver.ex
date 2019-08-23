# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Receiver do
  alias Pleroma.Web.Federator

  # Note: `max_attempts` is intended to be overridden in `new/1` call
  use Oban.Worker,
    queue: "federator_incoming",
    max_attempts: 1

  @impl Oban.Worker
  def perform(%{"op" => "incoming_doc", "body" => doc}, _job) do
    Federator.perform(:incoming_doc, doc)
  end

  def perform(%{"op" => "incoming_ap_doc", "params" => params}, _job) do
    Federator.perform(:incoming_ap_doc, params)
  end
end
