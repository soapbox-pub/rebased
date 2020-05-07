# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Notification do
  use Ecto.Schema

  alias Pleroma.Activity
  alias Pleroma.FollowingRelationship
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Pagination
  alias Pleroma.Repo
  alias Pleroma.ThreadMute
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
    ap_id_relationships =
      [:block] ++
        if opts[@include_muted_option], do: [], else: [:notification_mute]

    preloaded_ap_ids = User.outgoing_relationships_ap_ids(user, ap_id_relationships)

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
  end

  # Excludes blocked users and non-followed domain-blocked users
  defp exclude_blocked(query, user, opts) do
    blocked_ap_ids = opts[:blocked_users_ap_ids] || User.blocked_users_ap_ids(user)

    query
    |> where([n, a], a.actor not in ^blocked_ap_ids)
    |> FollowingRelationship.keep_following_or_not_domain_blocked(user)
  end

  defp exclude_notification_muted(query, _, %{@include_muted_option => true}) do
    query
  end

  defp exclude_notification_muted(query, user, opts) do
    notification_muted_ap_ids =
      opts[:notification_muted_users_ap_ids] || User.notification_muted_users_ap_ids(user)

    query
    |> where([n, a], a.actor not in ^notification_muted_ap_ids)
    |> join(:left, [n, a], tm in ThreadMute,
      on: tm.user_id == ^user.id and tm.context == fragment("?->>'context'", a.data)
    )
    |> where([n, a, o, tm], is_nil(tm.user_id))
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

  def dismiss(%Pleroma.Activity{} = activity) do
    Notification
    |> where([n], n.activity_id == ^activity.id)
    |> Repo.delete_all()
    |> case do
      {_, notifications} -> {:ok, notifications}
      _ -> {:error, "Cannot dismiss notification"}
    end
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

    if object && object.data["type"] == "Answer" do
      {:ok, []}
    else
      do_create_notifications(activity)
    end
  end

  def create_notifications(%Activity{data: %{"type" => type}} = activity)
      when type in ["Follow", "Like", "Announce", "Move", "EmojiReact"] do
    do_create_notifications(activity)
  end

  def create_notifications(_), do: {:ok, []}

  defp do_create_notifications(%Activity{} = activity) do
    {enabled_receivers, disabled_receivers} = get_notified_from_activity(activity)
    potential_receivers = enabled_receivers ++ disabled_receivers

    notifications =
      Enum.map(potential_receivers, fn user ->
        do_send = user in enabled_receivers
        create_notification(activity, user, do_send)
      end)

    {:ok, notifications}
  end

  # TODO move to sql, too.
  def create_notification(%Activity{} = activity, %User{} = user, do_send \\ true) do
    unless skip?(activity, user) do
      notification = %Notification{user_id: user.id, activity: activity}
      {:ok, notification} = Repo.insert(notification)

      if do_send do
        Streamer.stream(["user", "user:notification"], notification)
        Push.send(notification)
      end

      notification
    end
  end

  @doc """
  Returns a tuple with 2 elements:
    {notification-enabled receivers, currently disabled receivers (blocking / [thread] muting)}

  NOTE: might be called for FAKE Activities, see ActivityPub.Utils.get_notified_from_object/1
  """
  @spec get_notified_from_activity(Activity.t(), boolean()) :: {list(User.t()), list(User.t())}
  def get_notified_from_activity(activity, local_only \\ true)

  def get_notified_from_activity(%Activity{data: %{"type" => type}} = activity, local_only)
      when type in ["Create", "Like", "Announce", "Follow", "Move", "EmojiReact"] do
    potential_receiver_ap_ids = get_potential_receiver_ap_ids(activity)

    potential_receivers = User.get_users_from_set(potential_receiver_ap_ids, local_only)

    notification_enabled_ap_ids =
      potential_receiver_ap_ids
      |> exclude_domain_blocker_ap_ids(activity, potential_receivers)
      |> exclude_relationship_restricted_ap_ids(activity)
      |> exclude_thread_muter_ap_ids(activity)

    notification_enabled_users =
      Enum.filter(potential_receivers, fn u -> u.ap_id in notification_enabled_ap_ids end)

    {notification_enabled_users, potential_receivers -- notification_enabled_users}
  end

  def get_notified_from_activity(_, _local_only), do: {[], []}

  # For some actitivies, only notifity the author of the object
  def get_potential_receiver_ap_ids(%{data: %{"type" => type, "object" => object_id}})
      when type in ~w{Like Announce EmojiReact} do
    case Object.get_cached_by_ap_id(object_id) do
      %Object{data: %{"actor" => actor}} ->
        [actor]

      _ ->
        []
    end
  end

  def get_potential_receiver_ap_ids(activity) do
    []
    |> Utils.maybe_notify_to_recipients(activity)
    |> Utils.maybe_notify_mentioned_recipients(activity)
    |> Utils.maybe_notify_subscribers(activity)
    |> Utils.maybe_notify_followers(activity)
    |> Enum.uniq()
  end

  @doc "Filters out AP IDs domain-blocking and not following the activity's actor"
  def exclude_domain_blocker_ap_ids(ap_ids, activity, preloaded_users \\ [])

  def exclude_domain_blocker_ap_ids([], _activity, _preloaded_users), do: []

  def exclude_domain_blocker_ap_ids(ap_ids, %Activity{} = activity, preloaded_users) do
    activity_actor_domain = activity.actor && URI.parse(activity.actor).host

    users =
      ap_ids
      |> Enum.map(fn ap_id ->
        Enum.find(preloaded_users, &(&1.ap_id == ap_id)) ||
          User.get_cached_by_ap_id(ap_id)
      end)
      |> Enum.filter(& &1)

    domain_blocker_ap_ids = for u <- users, activity_actor_domain in u.domain_blocks, do: u.ap_id

    domain_blocker_follower_ap_ids =
      if Enum.any?(domain_blocker_ap_ids) do
        activity
        |> Activity.user_actor()
        |> FollowingRelationship.followers_ap_ids(domain_blocker_ap_ids)
      else
        []
      end

    ap_ids
    |> Kernel.--(domain_blocker_ap_ids)
    |> Kernel.++(domain_blocker_follower_ap_ids)
  end

  @doc "Filters out AP IDs of users basing on their relationships with activity actor user"
  def exclude_relationship_restricted_ap_ids([], _activity), do: []

  def exclude_relationship_restricted_ap_ids(ap_ids, %Activity{} = activity) do
    relationship_restricted_ap_ids =
      activity
      |> Activity.user_actor()
      |> User.incoming_relationships_ungrouped_ap_ids([
        :block,
        :notification_mute
      ])

    Enum.uniq(ap_ids) -- relationship_restricted_ap_ids
  end

  @doc "Filters out AP IDs of users who mute activity thread"
  def exclude_thread_muter_ap_ids([], _activity), do: []

  def exclude_thread_muter_ap_ids(ap_ids, %Activity{} = activity) do
    thread_muter_ap_ids = ThreadMute.muter_ap_ids(activity.data["context"])

    Enum.uniq(ap_ids) -- thread_muter_ap_ids
  end

  @spec skip?(Activity.t(), User.t()) :: boolean()
  def skip?(%Activity{} = activity, %User{} = user) do
    [
      :self,
      :followers,
      :follows,
      :non_followers,
      :non_follows,
      :recently_followed
    ]
    |> Enum.find(&skip?(&1, activity, user))
  end

  def skip?(_, _), do: false

  @spec skip?(atom(), Activity.t(), User.t()) :: boolean()
  def skip?(:self, %Activity{} = activity, %User{} = user) do
    activity.data["actor"] == user.ap_id
  end

  def skip?(
        :followers,
        %Activity{} = activity,
        %User{notification_settings: %{followers: false}} = user
      ) do
    actor = activity.data["actor"]
    follower = User.get_cached_by_ap_id(actor)
    User.following?(follower, user)
  end

  def skip?(
        :non_followers,
        %Activity{} = activity,
        %User{notification_settings: %{non_followers: false}} = user
      ) do
    actor = activity.data["actor"]
    follower = User.get_cached_by_ap_id(actor)
    !User.following?(follower, user)
  end

  def skip?(
        :follows,
        %Activity{} = activity,
        %User{notification_settings: %{follows: false}} = user
      ) do
    actor = activity.data["actor"]
    followed = User.get_cached_by_ap_id(actor)
    User.following?(user, followed)
  end

  def skip?(
        :non_follows,
        %Activity{} = activity,
        %User{notification_settings: %{non_follows: false}} = user
      ) do
    actor = activity.data["actor"]
    followed = User.get_cached_by_ap_id(actor)
    !User.following?(user, followed)
  end

  # To do: consider defining recency in hours and checking FollowingRelationship with a single SQL
  def skip?(:recently_followed, %Activity{data: %{"type" => "Follow"}} = activity, %User{} = user) do
    actor = activity.data["actor"]

    Notification.for_user(user)
    |> Enum.any?(fn
      %{activity: %{data: %{"type" => "Follow", "actor" => ^actor}}} -> true
      _ -> false
    end)
  end

  def skip?(_, _, _), do: false
end
