# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.MuteExpireWorker do
  use Pleroma.Workers.WorkerHelper, queue: "mute_expire"

  @impl Oban.Worker
  def perform(%Job{args: %{"op" => "unmute_user", "muter_id" => muter_id, "mutee_id" => mutee_id}}) do
    muter = Pleroma.User.get_by_id(muter_id)
    mutee = Pleroma.User.get_by_id(mutee_id)
    Pleroma.User.unmute(muter, mutee)
    :ok
  end

  def perform(%Job{
        args: %{"op" => "unmute_conversation", "user_id" => user_id, "activity_id" => activity_id}
      }) do
    user = Pleroma.User.get_by_id(user_id)
    activity = Pleroma.Activity.get_by_id(activity_id)
    Pleroma.Web.CommonAPI.remove_mute(user, activity)
    :ok
  end
end
