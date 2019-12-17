# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Notification do
  use Ecto.Schema

  alias Pleroma.Activity
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Pagination
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.Push
  alias Pleroma.Web.Streamer

  import Ecto.Query
  import Ecto.Changeset
  require Logger

  @type t :: %__MODULE__{}

  @include_muted_option :with_muted

  schema "notifications" do
    field(:seen, :boolean, default: false)
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    belongs_to(:activity, Activity, type: FlakeId.Ecto.CompatType)

    timestamps()
  end

  def changeset(%Notification{} = notification, attrs) do
    notification
    |> cast(attrs, [:seen])
  end

  defp for_user_query_ap_id_opts(user, opts) do
    ap_id_relations =
      [:block] ++
        if opts[@include_muted_option], do: [], else: [:notification_mute]

    preloaded_ap_ids = User.outgoing_relations_ap_ids(user, ap_id_relations)

    exclude_blocked_opts = Map.merge(%{blocked_users_ap_ids: preloaded_ap_ids[:block]}, opts)

    exclude_notification_muted_opts =
      Map.merge(%{notification_muted_users_ap_ids: preloaded_ap_ids[:notification_mute]}, opts)

    {exclude_blocked_opts, exclude_notification_muted_opts}
  end

  def for_user_query(user, opts \\ %{}) do
    {exclude_blocked_opts, exclude_notification_muted_opts} =
      for_user_query_ap_id_opts(user, opts)

    Notification
    |> where(user_id: ^user.id)
    |> where(
      [n, a],
      fragment(
        "? not in (SELECT ap_id FROM users WHERE deactivated = 'true')",
        a.actor
      )
    )
    |> join(:inner, [n], activity in assoc(n, :activity))
    |> join(:left, [n, a], object in Object,
      on:
        fragment(
          "(?->>'id') = COALESCE((? -> 'object'::text) ->> 'id'::text)",
          object.data,
          a.data
        )
    )
    |> preload([n, a, o], activity: {a, object: o})
    |> exclude_notification_muted(user, exclude_notification_muted_opts)
    |> exclude_blocked(user, exclude_blocked_opts)
    |> exclude_visibility(opts)
    |> exclude_move(opts)
  end

  defp exclude_blocked(query, user, opts) do
    blocked_ap_ids = opts[:blocked_users_ap_ids] || User.blocked_users_ap_ids(user)

    query
    |> where([n, a], a.actor not in ^blocked_ap_ids)
    |> where(
      [n, a],
      fragment("substring(? from '.*://([^/]*)')", a.actor) not in ^user.domain_blocks
    )
  end

  defp exclude_notification_muted(query, _, %{@include_muted_option => true}) do
    query
  end

  defp exclude_notification_muted(query, user, opts) do
    notification_muted_ap_ids =
      opts[:notification_muted_users_ap_ids] || User.notification_muted_users_ap_ids(user)

    query
    |> where([n, a], a.actor not in ^notification_muted_ap_ids)
    |> join(:left, [n, a], tm in Pleroma.ThreadMute,
      on: tm.user_id == ^user.id and tm.context == fragment("?->>'context'", a.data)
    )
    |> where([n, a, o, tm], is_nil(tm.user_id))
  end

  defp exclude_move(query, %{with_move: true}) do
    query
  end

  defp exclude_move(query, _opts) do
    where(query, [n, a], fragment("?->>'type' != 'Move'", a.data))
  end

  @valid_visibilities ~w[direct unlisted public private]

  defp exclude_visibility(query, %{exclude_visibilities: visibility})
       when is_list(visibility) do
    if Enum.all?(visibility, &(&1 in @valid_visibilities)) do
      query
      |> join(:left, [n, a], mutated_activity in Pleroma.Activity,
        on:
          fragment("?->>'context'", a.data) ==
            fragment("?->>'context'", mutated_activity.data) and
            fragment("(?->>'type' = 'Like' or ?->>'type' = 'Announce')", a.data, a.data) and
            fragment("?->>'type'", mutated_activity.data) == "Create",
        as: :mutated_activity
      )
      |> where(
        [n, a, mutated_activity: mutated_activity],
        not fragment(
          """
          CASE WHEN (?->>'type') = 'Like' or (?->>'type') = 'Announce'
            THEN (activity_visibility(?, ?, ?) = ANY (?))
            ELSE (activity_visibility(?, ?, ?) = ANY (?)) END
          """,
          a.data,
          a.data,
          mutated_activity.actor,
          mutated_activity.recipients,
          mutated_activity.data,
          ^visibility,
          a.actor,
          a.recipients,
          a.data,
          ^visibility
        )
      )
    else
      Logger.error("Could not exclude visibility to #{visibility}")
      query
    end
  end

  defp exclude_visibility(query, %{exclude_visibilities: visibility})
       when visibility in @valid_visibilities do
    exclude_visibility(query, [visibility])
  end

  defp exclude_visibility(query, %{exclude_visibilities: visibility})
       when visibility not in @valid_visibilities do
    Logger.error("Could not exclude visibility to #{visibility}")
    query
  end

  defp exclude_visibility(query, _visibility), do: query

  def for_user(user, opts \\ %{}) do
    user
    |> for_user_query(opts)
    |> Pagination.fetch_paginated(opts)
  end

  @doc """
  Returns notifications for user received since given date.

  ## Examples

      iex> Pleroma.Notification.for_user_since(%Pleroma.User{}, ~N[2019-04-13 11:22:33])
      [%Pleroma.Notification{}, %Pleroma.Notification{}]

      iex> Pleroma.Notification.for_user_since(%Pleroma.User{}, ~N[2019-04-15 11:22:33])
      []
  """
  @spec for_user_since(Pleroma.User.t(), NaiveDateTime.t()) :: [t()]
  def for_user_since(user, date) do
    from(n in for_user_query(user),
      where: n.updated_at > ^date
    )
    |> Repo.all()
  end

  def set_read_up_to(%{id: user_id} = _user, id) do
    query =
      from(
        n in Notification,
        where: n.user_id == ^user_id,
        where: n.id <= ^id,
        where: n.seen == false,
        update: [
          set: [
            seen: true,
            updated_at: ^NaiveDateTime.utc_now()
          ]
        ],
        # Ideally we would preload object and activities here
        # but Ecto does not support preloads in update_all
        select: n.id
      )

    {_, notification_ids} = Repo.update_all(query, [])

    Notification
    |> where([n], n.id in ^notification_ids)
    |> join(:inner, [n], activity in assoc(n, :activity))
    |> join(:left, [n, a], object in Object,
      on:
        fragment(
          "(?->>'id') = COALESCE((? -> 'object'::text) ->> 'id'::text)",
          object.data,
          a.data
        )
    )
    |> preload([n, a, o], activity: {a, object: o})
    |> Repo.all()
  end

  def read_one(%User{} = user, notification_id) do
    with {:ok, %Notification{} = notification} <- get(user, notification_id) do
      notification
      |> changeset(%{seen: true})
      |> Repo.update()
    end
  end

  def get(%{id: user_id} = _user, id) do
    query =
      from(
        n in Notification,
        where: n.id == ^id,
        join: activity in assoc(n, :activity),
        preload: [activity: activity]
      )

    notification = Repo.one(query)

    case notification do
      %{user_id: ^user_id} ->
        {:ok, notification}

      _ ->
        {:error, "Cannot get notification"}
    end
  end

  def clear(user) do
    from(n in Notification, where: n.user_id == ^user.id)
    |> Repo.delete_all()
  end

  def destroy_multiple(%{id: user_id} = _user, ids) do
    from(n in Notification,
      where: n.id in ^ids,
      where: n.user_id == ^user_id
    )
    |> Repo.delete_all()
  end

  def dismiss(%{id: user_id} = _user, id) do
    notification = Repo.get(Notification, id)

    case notification do
      %{user_id: ^user_id} ->
        Repo.delete(notification)

      _ ->
        {:error, "Cannot dismiss notification"}
    end
  end

  def create_notifications(%Activity{data: %{"to" => _, "type" => "Create"}} = activity) do
    object = Object.normalize(activity)

    unless object && object.data["type"] == "Answer" do
      users = get_notified_from_activity(activity)
      notifications = Enum.map(users, fn user -> create_notification(activity, user) end)
      {:ok, notifications}
    else
      {:ok, []}
    end
  end

  def create_notifications(%Activity{data: %{"type" => type}} = activity)
      when type in ["Like", "Announce", "Follow", "Move"] do
    notifications =
      activity
      |> get_notified_from_activity()
      |> Enum.map(&create_notification(activity, &1))

    {:ok, notifications}
  end

  def create_notifications(_), do: {:ok, []}

  # TODO move to sql, too.
  def create_notification(%Activity{} = activity, %User{} = user) do
    unless skip?(activity, user) do
      notification = %Notification{user_id: user.id, activity: activity}
      {:ok, notification} = Repo.insert(notification)

      ["user", "user:notification"]
      |> Streamer.stream(notification)

      Push.send(notification)
      notification
    end
  end

  def get_notified_from_activity(activity, local_only \\ true)

  def get_notified_from_activity(%Activity{data: %{"type" => type}} = activity, local_only)
      when type in ["Create", "Like", "Announce", "Follow", "Move"] do
    []
    |> Utils.maybe_notify_to_recipients(activity)
    |> Utils.maybe_notify_mentioned_recipients(activity)
    |> Utils.maybe_notify_subscribers(activity)
    |> Utils.maybe_notify_followers(activity)
    |> Enum.uniq()
    |> User.get_users_from_set(local_only)
  end

  def get_notified_from_activity(_, _local_only), do: []

  @spec skip?(Activity.t(), User.t()) :: boolean()
  def skip?(activity, user) do
    [
      :self,
      :followers,
      :follows,
      :non_followers,
      :non_follows,
      :recently_followed
    ]
    |> Enum.any?(&skip?(&1, activity, user))
  end

  @spec skip?(atom(), Activity.t(), User.t()) :: boolean()
  def skip?(:self, activity, user) do
    activity.data["actor"] == user.ap_id
  end

  def skip?(
        :followers,
        activity,
        %{notification_settings: %{followers: false}} = user
      ) do
    actor = activity.data["actor"]
    follower = User.get_cached_by_ap_id(actor)
    User.following?(follower, user)
  end

  def skip?(
        :non_followers,
        activity,
        %{notification_settings: %{non_followers: false}} = user
      ) do
    actor = activity.data["actor"]
    follower = User.get_cached_by_ap_id(actor)
    !User.following?(follower, user)
  end

  def skip?(:follows, activity, %{notification_settings: %{follows: false}} = user) do
    actor = activity.data["actor"]
    followed = User.get_cached_by_ap_id(actor)
    User.following?(user, followed)
  end

  def skip?(
        :non_follows,
        activity,
        %{notification_settings: %{non_follows: false}} = user
      ) do
    actor = activity.data["actor"]
    followed = User.get_cached_by_ap_id(actor)
    !User.following?(user, followed)
  end

  def skip?(:recently_followed, %{data: %{"type" => "Follow"}} = activity, user) do
    actor = activity.data["actor"]

    Notification.for_user(user)
    |> Enum.any?(fn
      %{activity: %{data: %{"type" => "Follow", "actor" => ^actor}}} -> true
      _ -> false
    end)
  end

  def skip?(_, _, _), do: false
end
