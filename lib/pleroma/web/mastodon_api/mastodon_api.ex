defmodule Pleroma.Web.MastodonAPI.MastodonAPI do
  import Ecto.Query
  import Ecto.Changeset

  alias Pleroma.Activity
  alias Pleroma.Notification
  alias Pleroma.Pagination
  alias Pleroma.ScheduledActivity
  alias Pleroma.User

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
    |> Notification.for_user_query()
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
      exclude_types: {:array, :string}
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
