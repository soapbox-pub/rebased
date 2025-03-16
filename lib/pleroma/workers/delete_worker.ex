# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.DeleteWorker do
  alias Pleroma.Instances.Instance
  alias Pleroma.User

  use Oban.Worker, queue: :slow

  @impl true
  def perform(%Job{args: %{"op" => "delete_user", "user_id" => user_id}}) do
    user = User.get_cached_by_id(user_id)
    User.perform(:delete, user)
  end

  def perform(%Job{args: %{"op" => "delete_instance", "host" => host}}) do
    Instance.perform(:delete_instance, host)
  end

  @impl true
  def timeout(_job), do: :timer.seconds(900)
end
