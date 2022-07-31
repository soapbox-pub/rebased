# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.BackgroundWorker do
  alias Pleroma.Instances.Instance
  alias Pleroma.User

  use Pleroma.Workers.WorkerHelper, queue: "background"

  @impl Oban.Worker

  def perform(%Job{args: %{"op" => "user_activation", "user_id" => user_id, "status" => status}}) do
    user = User.get_cached_by_id(user_id)
    User.perform(:set_activation_async, user, status)
  end

  def perform(%Job{args: %{"op" => "delete_user", "user_id" => user_id}}) do
    user = User.get_cached_by_id(user_id)
    User.perform(:delete, user)
  end

  def perform(%Job{args: %{"op" => "force_password_reset", "user_id" => user_id}}) do
    user = User.get_cached_by_id(user_id)
    User.perform(:force_password_reset, user)
  end

  def perform(%Job{args: %{"op" => op, "user_id" => user_id, "identifiers" => identifiers}})
      when op in ["blocks_import", "follow_import", "mutes_import"] do
    user = User.get_cached_by_id(user_id)
    {:ok, User.Import.perform(String.to_atom(op), user, identifiers)}
  end

  def perform(%Job{
        args: %{"op" => "move_following", "origin_id" => origin_id, "target_id" => target_id}
      }) do
    origin = User.get_cached_by_id(origin_id)
    target = User.get_cached_by_id(target_id)

    Pleroma.FollowingRelationship.move_following(origin, target)
  end

  def perform(%Job{args: %{"op" => "delete_instance", "host" => host}}) do
    Instance.perform(:delete_instance, host)
  end
end
