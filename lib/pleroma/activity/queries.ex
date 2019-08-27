# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Activity.Queries do
  @moduledoc """
  Contains queries for Activity.
  """

  import Ecto.Query, only: [from: 2]

  @type query :: Ecto.Queryable.t() | Activity.t()

  alias Pleroma.Activity

  @spec by_actor(query, String.t()) :: query
  def by_actor(query \\ Activity, actor) do
    from(
      activity in query,
      where: fragment("(?)->>'actor' = ?", activity.data, ^actor)
    )
  end

  @spec by_object_id(query, String.t()) :: query
  def by_object_id(query \\ Activity, object_id) do
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

  @spec by_type(query, String.t()) :: query
  def by_type(query \\ Activity, activity_type) do
    from(
      activity in query,
      where: fragment("(?)->>'type' = ?", activity.data, ^activity_type)
    )
  end

  @spec limit(query, pos_integer()) :: query
  def limit(query \\ Activity, limit) do
    from(activity in query, limit: ^limit)
  end
end
