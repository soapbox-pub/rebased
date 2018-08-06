defmodule Pleroma.Web.ActivityPub.Relay do
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  require Logger

  def get_actor do
    User.get_or_create_instance_user()
  end

  def follow(target_instance) do
    with %User{} = local_user <- get_actor(),
         %User{} = target_user <- User.get_or_fetch_by_ap_id(target_instance),
         {:ok, activity} <- ActivityPub.follow(local_user, target_user) do
      ActivityPub.publish(local_user, activity)
      Logger.info("relay: followed instance: #{target_instance}; id=#{activity.data["id"]}")
    else
      e -> Logger.error("error: #{inspect(e)}")
    end

    :ok
  end

  def unfollow(target_instance) do
    with %User{} = local_user <- get_actor(),
         %User{} = target_user <- User.get_or_fetch_by_ap_id(target_instance),
         {:ok, activity} <- ActivityPub.unfollow(local_user, target_user) do
      ActivityPub.publish(local_user, activity)
      Logger.info("relay: unfollowed instance: #{target_instance}: id=#{activity.data["id"]}")
    else
      e -> Logger.error("error: #{inspect(e)}")
    end

    :ok
  end
end
