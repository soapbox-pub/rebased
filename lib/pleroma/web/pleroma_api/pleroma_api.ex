defmodule Pleroma.Web.PleromaAPI.PleromaAPI do
  import Ecto.Query
  import Ecto.Changeset

  alias Pleroma.Activity
  alias Pleroma.Pagination
  alias Pleroma.SubscriptionNotification

  def get_subscription_notifications(user, params \\ %{}) do
    options = cast_params(params)

    user
    |> SubscriptionNotification.for_user_query(options)
    |> restrict(:exclude_types, options)
    |> Pagination.fetch_paginated(params)
  end

  defp cast_params(params) do
    param_types = %{
      exclude_types: {:array, :string},
      reblogs: :boolean,
      with_muted: :boolean
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
