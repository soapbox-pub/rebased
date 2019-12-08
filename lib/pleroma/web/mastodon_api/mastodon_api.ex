# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MastodonAPI do
  import Ecto.Query
  import Ecto.Changeset

  alias Pleroma.Activity
  alias Pleroma.Notification
  alias Pleroma.Pagination
  alias Pleroma.ScheduledActivity
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  @spec follow(User.t(), User.t(), map) :: {:ok, User.t()} | {:error, String.t()}
  def follow(follower, followed, params \\ %{}) do
    result =
      if not User.following?(follower, followed) do
        CommonAPI.follow(follower, followed)
      else
        {:ok, follower, followed, nil}
      end

    with {:ok, follower, _followed, _} <- result do
      options = cast_params(params)
      set_reblogs_visibility(options[:reblogs], result)
      {:ok, follower}
    end
  end

  defp set_reblogs_visibility(false, {:ok, follower, followed, _}) do
    CommonAPI.hide_reblogs(follower, followed)
  end

  defp set_reblogs_visibility(_, {:ok, follower, followed, _}) do
    CommonAPI.show_reblogs(follower, followed)
  end

  @spec get_followers(User.t(), map()) :: list(User.t())
  def get_followers(user, params \\ %{}) do
    user
    |> User.get_followers_query()
    |> Pagination.fetch_paginated(params)
  end

  def get_friends(user, params \\ %{}) do
    user
    |> User.get_friends_query()
    |> Pagination.fetch_paginated(params)
  end

  def get_notifications(user, params \\ %{}) do
    options = cast_params(params)

    user
    |> Notification.for_user_query(options)
    |> restrict(:exclude_types, options)
    |> Pagination.fetch_paginated(params)
  end

  def get_scheduled_activities(user, params \\ %{}) do
    user
    |> ScheduledActivity.for_user_query()
    |> Pagination.fetch_paginated(params)
  end

  defp cast_params(params) do
    param_types = %{
      exclude_types: {:array, :string},
      exclude_visibilities: {:array, :string},
      reblogs: :boolean,
      with_muted: :boolean,
      with_move: :boolean
    }

    changeset = cast({%{}, param_types}, params, Map.keys(param_types))
    changeset.changes
  end

  defp restrict(query, :exclude_types, %{exclude_types: mastodon_types = [_ | _]}) do
    ap_types =
      mastodon_types
      |> Enum.map(&Activity.from_mastodon_notification_type/1)
      |> Enum.filter(& &1)

    query
    |> where([q, a], not fragment("? @> ARRAY[?->>'type']::varchar[]", ^ap_types, a.data))
  end

  defp restrict(query, _, _), do: query
end
