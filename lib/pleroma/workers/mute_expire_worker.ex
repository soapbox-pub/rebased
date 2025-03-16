# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.MuteExpireWorker do
  use Oban.Worker, queue: :background

  @impl true
  def perform(%Job{args: %{"op" => "unmute_user", "muter_id" => muter_id, "mutee_id" => mutee_id}}) do
    Pleroma.User.unmute(muter_id, mutee_id)
    :ok
  end

  def perform(%Job{
        args: %{"op" => "unmute_conversation", "user_id" => user_id, "activity_id" => activity_id}
      }) do
    Pleroma.Web.CommonAPI.remove_mute(activity_id, user_id)
    :ok
  end

  @impl true
  def timeout(_job), do: :timer.seconds(5)
end
