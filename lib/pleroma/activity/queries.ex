# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Activity.Queries do
  @moduledoc """
  Contains queries for Activity.
  """

  import Ecto.Query, only: [from: 2, where: 3]

  @type query :: Ecto.Queryable.t() | Activity.t()

  alias Pleroma.Activity
  alias Pleroma.User

  @spec by_ap_id(query, String.t()) :: query
  def by_ap_id(query \\ Activity, ap_id) do
    from(
      activity in query,
      where: fragment("(?)->>'id' = ?", activity.data, ^to_string(ap_id))
    )
  end

  @spec by_actor(query, String.t()) :: query
  def by_actor(query \\ Activity, actor) do
    from(
      activity in query,
      where: fragment("(?)->>'actor' = ?", activity.data, ^actor)
    )
  end

  @spec by_author(query, String.t()) :: query
  def by_author(query \\ Activity, %User{ap_id: ap_id}) do
    from(a in query, where: a.actor == ^ap_id)
  end

  @spec by_object_id(query, String.t() | [String.t()]) :: query
  def by_object_id(query \\ Activity, object_id)

  def by_object_id(query, object_ids) when is_list(object_ids) do
    from(
      activity in query,
      where:
        fragment(
          "coalesce((?)->'object'->>'id', (?)->>'object') = ANY(?)",
          activity.data,
          activity.data,
          ^object_ids
        )
    )
  end

  def by_object_id(query, object_id) when is_binary(object_id) do
    from(activity in query,
      where:
        fragment(
          "coalesce((?)->'object'->>'id', (?)->>'object') = ?",
          activity.data,
          activity.data,
          ^object_id
        )
    )
  end

  @spec by_object_in_reply_to_id(query, String.t(), keyword()) :: query
  def by_object_in_reply_to_id(query, in_reply_to_id, opts \\ []) do
    query =
      if opts[:skip_preloading] do
        Activity.with_joined_object(query)
      else
        Activity.with_preloaded_object(query)
      end

    where(
      query,
      [activity, object: o],
      fragment("(?)->>'inReplyTo' = ?", o.data, ^to_string(in_reply_to_id))
    )
  end

  @spec by_type(query, String.t()) :: query
  def by_type(query \\ Activity, activity_type) do
    from(
      activity in query,
      where: fragment("(?)->>'type' = ?", activity.data, ^activity_type)
    )
  end

  @spec exclude_type(query, String.t()) :: query
  def exclude_type(query \\ Activity, activity_type) do
    from(
      activity in query,
      where: fragment("(?)->>'type' != ?", activity.data, ^activity_type)
    )
  end

  def exclude_authors(query \\ Activity, actors) do
    from(activity in query, where: activity.actor not in ^actors)
  end
end
