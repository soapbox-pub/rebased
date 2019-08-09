# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Publisher do
  alias Pleroma.Activity
  alias Pleroma.User

  # Note: `max_attempts` is intended to be overridden in `new/1` call
  use Oban.Worker,
    queue: "federator_outgoing",
    max_attempts: Pleroma.Config.get([:workers, :retries, :compile_time_default])

  @impl Oban.Worker
  def perform(%{"op" => "publish", "activity_id" => activity_id}) do
    with %Activity{} = activity <- Activity.get_by_id(activity_id) do
      perform_publish(activity)
    else
      _ -> raise "Non-existing activity: #{activity_id}"
    end
  end

  def perform(%{"op" => "publish_one", "module" => module_name, "params" => params}) do
    module_name
    |> String.to_atom()
    |> apply(:publish_one, [params])
  end

  def perform_publish(%Activity{} = activity) do
    with %User{} = actor <- User.get_cached_by_ap_id(activity.data["actor"]),
         {:ok, actor} <- User.ensure_keys_present(actor) do
      Pleroma.Web.Federator.Publisher.publish(actor, activity)
    end
  end
end
