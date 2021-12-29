# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.MigrationHelper.LegacyActivity do
  @moduledoc """
  Legacy "activities" schema needed for old migrations.
  """
  use Ecto.Schema

  alias Pleroma.Activity.Queries
  alias Pleroma.Bookmark
  alias Pleroma.MigrationHelper.LegacyActivity, as: Activity
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.ReportNote
  alias Pleroma.User

  import Ecto.Query

  @type t :: %__MODULE__{}
  @type actor :: String.t()

  @primary_key {:id, FlakeId.Ecto.CompatType, autogenerate: true}

  schema "activities" do
    field(:data, :map)
    field(:local, :boolean, default: true)
    field(:actor, :string)
    field(:recipients, {:array, :string}, default: [])
    field(:thread_muted?, :boolean, virtual: true)

    # A field that can be used if you need to join some kind of other
    # id to order / paginate this field by
    field(:pagination_id, :string, virtual: true)

    # This is a fake relation,
    # do not use outside of with_preloaded_user_actor/with_joined_user_actor
    has_one(:user_actor, User, on_delete: :nothing, foreign_key: :id)
    # This is a fake relation, do not use outside of with_preloaded_bookmark/get_bookmark
    has_one(:bookmark, Bookmark, foreign_key: :activity_id)
    # This is a fake relation, do not use outside of with_preloaded_report_notes
    has_many(:report_notes, ReportNote, foreign_key: :activity_id)
    has_many(:notifications, Notification, on_delete: :delete_all, foreign_key: :activity_id)

    # Attention: this is a fake relation, don't try to preload it blindly and expect it to work!
    # The foreign key is embedded in a jsonb field.
    #
    # To use it, you probably want to do an inner join and a preload:
    #
    # ```
    # |> join(:inner, [activity], o in Object,
    #      on: fragment("(?->>'id') = COALESCE((?)->'object'->> 'id', (?)->>'object')",
    #        o.data, activity.data, activity.data))
    # |> preload([activity, object], [object: object])
    # ```
    #
    # As a convenience, Activity.with_preloaded_object() sets up an inner join and preload for the
    # typical case.
    has_one(:object, Object, on_delete: :nothing, foreign_key: :id)

    timestamps()
  end

  def with_joined_object(query, join_type \\ :inner) do
    join(query, join_type, [activity], o in Object,
      on:
        fragment(
          "(?->>'id') = COALESCE(?->'object'->>'id', ?->>'object')",
          o.data,
          activity.data,
          activity.data
        ),
      as: :object
    )
  end

  def with_preloaded_object(query, join_type \\ :inner) do
    query
    |> has_named_binding?(:object)
    |> if(do: query, else: with_joined_object(query, join_type))
    |> preload([activity, object: object], object: object)
  end

  def all_by_ids_with_object(ids) do
    Activity
    |> where([a], a.id in ^ids)
    |> with_preloaded_object()
    |> Repo.all()
  end

  @doc """
  Accepts `ap_id` or list of `ap_id`.
  Returns a query.
  """
  @spec create_by_object_ap_id(String.t() | [String.t()]) :: Ecto.Queryable.t()
  def create_by_object_ap_id(ap_id) do
    Activity
    |> Queries.by_object_id(ap_id)
    |> Queries.by_type("Create")
  end
end
