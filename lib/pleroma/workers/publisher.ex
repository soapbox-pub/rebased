# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Publisher do
  use Oban.Worker, queue: "federator_outgoing", max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{module: module_name, params: params}}) do
    module_name
    |> String.to_atom()
    |> apply(:publish_one, [params])
  end
end
