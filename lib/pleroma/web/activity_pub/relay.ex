# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Relay do
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  require Logger

  def get_actor do
    "#{Pleroma.Web.Endpoint.url()}/relay"
    |> User.get_or_create_service_actor_by_ap_id()
  end

  def follow(target_instance) do
    with %User{} = local_user <- get_actor(),
         {:ok, %User{} = target_user} <- User.get_or_fetch_by_ap_id(target_instance),
         {:ok, activity} <- ActivityPub.follow(local_user, target_user) do
      Logger.info("relay: followed instance: #{target_instance}; id=#{activity.data["id"]}")
      {:ok, activity}
    else
      e ->
        Logger.error("error: #{inspect(e)}")
        {:error, e}
    end
  end

  def unfollow(target_instance) do
    with %User{} = local_user <- get_actor(),
         {:ok, %User{} = target_user} <- User.get_or_fetch_by_ap_id(target_instance),
         {:ok, activity} <- ActivityPub.unfollow(local_user, target_user) do
      Logger.info("relay: unfollowed instance: #{target_instance}: id=#{activity.data["id"]}")
      {:ok, activity}
    else
      e ->
        Logger.error("error: #{inspect(e)}")
        {:error, e}
    end
  end

  def publish(%Activity{data: %{"type" => "Create"}} = activity) do
    with %User{} = user <- get_actor(),
         %Object{} = object <- Object.normalize(activity) do
      ActivityPub.announce(user, object, nil, true, false)
    else
      e -> Logger.error("error: #{inspect(e)}")
    end
  end

  def publish(_), do: nil
end
