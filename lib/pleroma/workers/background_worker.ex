# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.BackgroundWorker do
  alias Pleroma.Activity
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.MRF.MediaProxyWarmingPolicy
  alias Pleroma.Web.OAuth.Token.CleanWorker

  # Note: `max_attempts` is intended to be overridden in `new/1` call
  use Oban.Worker,
    queue: "background",
    max_attempts: Pleroma.Config.get([:workers, :retries, :compile_time_default])

  @impl Oban.Worker
  def perform(%{"op" => "fetch_initial_posts", "user_id" => user_id}) do
    user = User.get_by_id(user_id)
    User.perform(:fetch_initial_posts, user)
  end

  def perform(%{"op" => "deactivate_user", "user_id" => user_id, "status" => status}) do
    user = User.get_by_id(user_id)
    User.perform(:deactivate_async, user, status)
  end

  def perform(%{"op" => "delete_user", "user_id" => user_id}) do
    user = User.get_by_id(user_id)
    User.perform(:delete, user)
  end

  def perform(%{
        "op" => "blocks_import",
        "blocker_id" => blocker_id,
        "blocked_identifiers" => blocked_identifiers
      }) do
    blocker = User.get_by_id(blocker_id)
    User.perform(:blocks_import, blocker, blocked_identifiers)
  end

  def perform(%{
        "op" => "follow_import",
        "follower_id" => follower_id,
        "followed_identifiers" => followed_identifiers
      }) do
    follower = User.get_by_id(follower_id)
    User.perform(:follow_import, follower, followed_identifiers)
  end

  def perform(%{"op" => "clean_expired_tokens"}) do
    CleanWorker.perform(:clean)
  end

  def perform(%{"op" => "media_proxy_preload", "message" => message}) do
    MediaProxyWarmingPolicy.perform(:preload, message)
  end

  def perform(%{"op" => "media_proxy_prefetch", "url" => url}) do
    MediaProxyWarmingPolicy.perform(:prefetch, url)
  end

  def perform(%{"op" => "fetch_data_for_activity", "activity_id" => activity_id}) do
    activity = Activity.get_by_id(activity_id)
    Pleroma.Web.RichMedia.Helpers.perform(:fetch, activity)
  end
end
