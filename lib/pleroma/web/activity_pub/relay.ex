# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Relay do
  alias Pleroma.Activity
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.CommonAPI
  require Logger

  @nickname "relay"

  @spec ap_id() :: String.t()
  def ap_id, do: "#{Pleroma.Web.Endpoint.url()}/#{@nickname}"

  @spec get_actor() :: User.t() | nil
  def get_actor, do: User.get_or_create_service_actor_by_ap_id(ap_id(), @nickname)

  @spec follow(String.t()) :: {:ok, Activity.t()} | {:error, any()}
  def follow(target_instance) do
    with %User{} = local_user <- get_actor(),
         {:ok, %User{} = target_user} <- User.get_or_fetch_by_ap_id(target_instance),
         {:ok, _, _, activity} <- CommonAPI.follow(local_user, target_user) do
      Logger.info("relay: followed instance: #{target_instance}; id=#{activity.data["id"]}")
      {:ok, activity}
    else
      error -> format_error(error)
    end
  end

  @spec unfollow(String.t(), map()) :: {:ok, Activity.t()} | {:error, any()}
  def unfollow(target_instance, opts \\ %{}) do
    with %User{} = local_user <- get_actor(),
         {:ok, target_user} <- fetch_target_user(target_instance, opts),
         {:ok, activity} <- ActivityPub.unfollow(local_user, target_user) do
      case target_user.id do
        nil -> User.update_following_count(local_user)
        _ -> User.unfollow(local_user, target_user)
      end

      Logger.info("relay: unfollowed instance: #{target_instance}: id=#{activity.data["id"]}")
      {:ok, activity}
    else
      error -> format_error(error)
    end
  end

  defp fetch_target_user(ap_id, opts) do
    case {opts[:force], User.get_or_fetch_by_ap_id(ap_id)} do
      {_, {:ok, %User{} = user}} -> {:ok, user}
      {true, _} -> {:ok, %User{ap_id: ap_id}}
      {_, error} -> error
    end
  end

  @spec publish(any()) :: {:ok, Activity.t()} | {:error, any()}
  def publish(%Activity{data: %{"type" => "Create"}} = activity) do
    with %User{} = user <- get_actor(),
         true <- Visibility.is_public?(activity) do
      CommonAPI.repeat(activity.id, user)
    else
      error -> format_error(error)
    end
  end

  def publish(_), do: {:error, "Not implemented"}

  @spec list() :: {:ok, [%{actor: String.t(), followed_back: boolean()}]} | {:error, any()}
  def list do
    with %User{} = user <- get_actor() do
      accepted =
        user
        |> following()
        |> Enum.map(fn actor -> %{actor: actor, followed_back: true} end)

      without_accept =
        user
        |> Pleroma.Activity.following_requests_for_actor()
        |> Enum.map(fn activity -> %{actor: activity.data["object"], followed_back: false} end)
        |> Enum.uniq()

      {:ok, accepted ++ without_accept}
    else
      error -> format_error(error)
    end
  end

  @spec following() :: [String.t()]
  def following do
    get_actor()
    |> following()
  end

  defp following(user) do
    user
    |> User.following_ap_ids()
    |> Enum.uniq()
  end

  defp format_error({:error, error}), do: format_error(error)

  defp format_error(error) do
    Logger.error("error: #{inspect(error)}")
    {:error, error}
  end
end
