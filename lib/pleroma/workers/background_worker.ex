# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.BackgroundWorker do
  alias Pleroma.User

  use Oban.Worker, queue: :background

  @impl true

  def perform(%Job{args: %{"op" => "user_activation", "user_id" => user_id, "status" => status}}) do
    user = User.get_cached_by_id(user_id)
    User.perform(:set_activation_async, user, status)
  end

  def perform(%Job{args: %{"op" => "force_password_reset", "user_id" => user_id}}) do
    user = User.get_cached_by_id(user_id)
    User.perform(:force_password_reset, user)
  end

  def perform(%Job{args: %{"op" => op, "user_id" => user_id, "actor" => actor}})
      when op in ["block_import", "follow_import", "mute_import"] do
    user = User.get_cached_by_id(user_id)
    User.Import.perform(String.to_existing_atom(op), user, actor)
  end

  def perform(%Job{
        args: %{"op" => "move_following", "origin_id" => origin_id, "target_id" => target_id}
      }) do
    origin = User.get_cached_by_id(origin_id)
    target = User.get_cached_by_id(target_id)

    Pleroma.FollowingRelationship.move_following(origin, target)
  end

  def perform(%Job{args: %{"op" => "verify_fields_links", "user_id" => user_id}}) do
    user = User.get_by_id(user_id)
    User.perform(:verify_fields_links, user)
  end

  @impl true
  def timeout(_job), do: :timer.seconds(900)
end
