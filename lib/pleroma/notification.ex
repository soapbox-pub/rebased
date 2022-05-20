# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Notification do
  use Ecto.Schema

  alias Ecto.Multi
  alias Pleroma.Activity
  alias Pleroma.FollowingRelationship
  alias Pleroma.Marker
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Pagination
  alias Pleroma.Repo
  alias Pleroma.ThreadMute
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
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
    # This is an enum type in the database. If you add a new notification type,
    # remember to add a migration to add it to the `notifications_type` enum
    # as well.
    field(:type, :string)
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    belongs_to(:activity, Activity, type: FlakeId.Ecto.CompatType)

    timestamps()
  end

  def update_notification_type(user, activity) do
    with %__MODULE__{} = notification <-
           Repo.get_by(__MODULE__, user_id: user.id, activity_id: activity.id) do
      type =
        activity
        |> type_from_activity()

      notification
      |> changeset(%{type: type})
      |> Repo.update()
    end
  end

  @spec unread_notifications_count(User.t()) :: integer()
  def unread_notifications_count(%User{id: user_id}) do
    from(q in __MODULE__,
      where: q.user_id == ^user_id and q.seen == false
    )
    |> Repo.aggregate(:count, :id)
  end

  @notification_types ~w{
    favourite
    follow
    follow_request
    mention
    move
    pleroma:chat_mention
    pleroma:emoji_reaction
    pleroma:report
    reblog
    poll
    status
  }

  def changeset(%Notification{} = notification, attrs) do
    notification
    |> cast(attrs, [:seen, :type])
    |> validate_inclusion(:type, @notification_types)
  end

  @spec last_read_query(User.t()) :: Ecto.Queryable.t()
  def last_read_query(user) do
    from(q in Pleroma.Notification,
      where: q.user_id == ^user.id,
      where: q.seen == true,
      select: type(q.id, :string),
      limit: 1,
      order_by: [desc: :id]
    )
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
    |> join(:inner, [n], activity in assoc(n, :activity))
    |> join(:left, [n, a], object in Object,
      on:
        fragment(
          "(?->>'id') = COALESCE(?->'object'->>'id', ?->>'object')",
          object.data,
          a.data,
          a.data
        )
    )
    |> join(:inner, [_n, a], u in User, on: u.ap_id == a.actor, as: :user_actor)
    |> preload([n, a, o], activity: {a, object: o})
    |> where([user_actor: user_actor], user_actor.is_active)
    |> exclude_notification_muted(user, exclude_notification_muted_opts)
    |> exclude_blocked(user, exclude_blocked_opts)
    |> exclude_blockers(user)
    |> exclude_filtered(user)
    |> exclude_visibility(opts)
  end

  # Excludes blocked users and non-followed domain-blocked users
  defp exclude_blocked(query, user, opts) do
    blocked_ap_ids = opts[:blocked_users_ap_ids] || User.blocked_users_ap_ids(user)

    query
    |> where([n, a], a.actor not in ^blocked_ap_ids)
    |> FollowingRelationship.keep_following_or_not_domain_blocked(user)
  end

  defp exclude_blockers(query, user) do
    if Pleroma.Config.get([:activitypub, :blockers_visible]) == true do
      query
    else
      blocker_ap_ids = User.incoming_relationships_ungrouped_ap_ids(user, [:block])

      query
      |> where([n, a], a.actor not in ^blocker_ap_ids)
    end
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
      on: tm.user_id == ^user.id and tm.context == fragment("?->>'context'", a.data),
      as: :thread_mute
    )
    |> where([thread_mute: thread_mute], is_nil(thread_mute.user_id))
  end

  defp exclude_filtered(query, user) do
    case Pleroma.Filter.compose_regex(user) do
      nil ->
        query

      regex ->
        from([_n, a, o] in query,
          where:
            fragment("not(?->>'content' ~* ?)", o.data, ^regex) or
              fragment("?->>'actor' = ?", o.data, ^user.ap_id)
        )
    end
  end

  @valid_visibilities ~w[direct unlisted public private]

  defp exclude_visibility(query, %{exclude_visibilities: visibility})
       when is_list(visibility) do
    if Enum.all?(visibility, &(&1 in @valid_visibilities)) do
      query
      |> join(:left, [n, a], mutated_activity in Pleroma.Activity,
        on:
          fragment(
            "COALESCE((?->'object')->>'id', ?->>'object')",
            a.data,
            a.data
          ) ==
            fragment(
              "COALESCE((?->'object')->>'id', ?->>'object')",
              mutated_activity.data,
              mutated_activity.data
            ) and
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

  def set_read_up_to(%{id: user_id} = user, id) do
    query =
      from(
        n in Notification,
        where: n.user_id == ^user_id,
        where: n.id <= ^id,
        where: n.seen == false,
        # Ideally we would preload object and activities here
        # but Ecto does not support preloads in update_all
        select: n.id
      )

    {:ok, %{ids: {_, notification_ids}}} =
      Multi.new()
      |> Multi.update_all(:ids, query, set: [seen: true, updated_at: NaiveDateTime.utc_now()])
      |> Marker.multi_set_last_read_id(user, "notifications")
      |> Repo.transaction()

    for_user_query(user)
    |> where([n], n.id in ^notification_ids)
    |> Repo.all()
  end

  @spec read_one(User.t(), String.t()) ::
          {:ok, Notification.t()} | {:error, Ecto.Changeset.t()} | nil
  def read_one(%User{} = user, notification_id) do
    with {:ok, %Notification{} = notification} <- get(user, notification_id) do
      Multi.new()
      |> Multi.update(:update, changeset(notification, %{seen: true}))
      |> Marker.multi_set_last_read_id(user, "notifications")
      |> Repo.transaction()
      |> case do
        {:ok, %{update: notification}} -> {:ok, notification}
        {:error, :update, changeset, _} -> {:error, changeset}
      end
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

  def destroy_multiple_from_types(%{id: user_id}, types) do
    from(n in Notification,
      where: n.user_id == ^user_id,
      where: n.type in ^types
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

  @spec create_notifications(Activity.t(), keyword()) :: {:ok, [Notification.t()] | []}
  def create_notifications(activity, options \\ [])

  def create_notifications(%Activity{data: %{"to" => _, "type" => "Create"}} = activity, options) do
    object = Object.normalize(activity, fetch: false)

    if object && object.data["type"] == "Answer" do
      {:ok, []}
    else
      do_create_notifications(activity, options)
    end
  end

  def create_notifications(%Activity{data: %{"type" => type}} = activity, options)
      when type in ["Follow", "Like", "Announce", "Move", "EmojiReact", "Flag"] do
    do_create_notifications(activity, options)
  end

  def create_notifications(_, _), do: {:ok, []}

  defp do_create_notifications(%Activity{} = activity, options) do
    do_send = Keyword.get(options, :do_send, true)

    {enabled_receivers, disabled_receivers} = get_notified_from_activity(activity)
    potential_receivers = enabled_receivers ++ disabled_receivers

    {enabled_subscribers, disabled_subscribers} = get_notified_subscribers_from_activity(activity)
    potential_subscribers = (enabled_subscribers ++ disabled_subscribers) -- potential_receivers

    notifications =
      (Enum.map(potential_receivers, fn user ->
         do_send = do_send && user in enabled_receivers
         create_notification(activity, user, do_send: do_send)
       end) ++
         Enum.map(potential_subscribers, fn user ->
           do_send = do_send && user in enabled_subscribers
           create_notification(activity, user, do_send: do_send, type: "status")
         end))
      |> Enum.reject(&is_nil/1)

    {:ok, notifications}
  end

  defp type_from_activity(%{data: %{"type" => type}} = activity) do
    case type do
      "Follow" ->
        if Activity.follow_accepted?(activity) do
          "follow"
        else
          "follow_request"
        end

      "Announce" ->
        "reblog"

      "Like" ->
        "favourite"

      "Move" ->
        "move"

      "EmojiReact" ->
        "pleroma:emoji_reaction"

      "Flag" ->
        "pleroma:report"

      # Compatibility with old reactions
      "EmojiReaction" ->
        "pleroma:emoji_reaction"

      "Create" ->
        activity
        |> type_from_activity_object()

      t ->
        raise "No notification type for activity type #{t}"
    end
  end

  defp type_from_activity_object(%{data: %{"type" => "Create", "object" => %{}}}), do: "mention"

  defp type_from_activity_object(%{data: %{"type" => "Create"}} = activity) do
    object = Object.get_by_ap_id(activity.data["object"])

    case object && object.data["type"] do
      "ChatMessage" -> "pleroma:chat_mention"
      _ -> "mention"
    end
  end

  # TODO move to sql, too.
  def create_notification(%Activity{} = activity, %User{} = user, opts \\ []) do
    do_send = Keyword.get(opts, :do_send, true)
    type = Keyword.get(opts, :type, type_from_activity(activity))

    unless skip?(activity, user, opts) do
      {:ok, %{notification: notification}} =
        Multi.new()
        |> Multi.insert(:notification, %Notification{
          user_id: user.id,
          activity: activity,
          seen: mark_as_read?(activity, user),
          type: type
        })
        |> Marker.multi_set_last_read_id(user, "notifications")
        |> Repo.transaction()

      if do_send do
        Streamer.stream(["user", "user:notification"], notification)
        Push.send(notification)
      end

      notification
    end
  end

  def create_poll_notifications(%Activity{} = activity) do
    with %Object{data: %{"type" => "Question", "actor" => actor} = data} <-
           Object.normalize(activity) do
      voters =
        case data do
          %{"voters" => voters} when is_list(voters) -> voters
          _ -> []
        end

      notifications =
        Enum.reduce([actor | voters], [], fn ap_id, acc ->
          with %User{local: true} = user <- User.get_by_ap_id(ap_id) do
            [create_notification(activity, user, type: "poll") | acc]
          else
            _ -> acc
          end
        end)

      {:ok, notifications}
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
      when type in ["Create", "Like", "Announce", "Follow", "Move", "EmojiReact", "Flag"] do
    potential_receiver_ap_ids = get_potential_receiver_ap_ids(activity)

    potential_receivers =
      User.get_users_from_set(potential_receiver_ap_ids, local_only: local_only)

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

  def get_notified_subscribers_from_activity(activity, local_only \\ true)

  def get_notified_subscribers_from_activity(
        %Activity{data: %{"type" => "Create"}} = activity,
        local_only
      ) do
    notification_enabled_ap_ids =
      []
      |> Utils.maybe_notify_subscribers(activity)

    potential_receivers =
      User.get_users_from_set(notification_enabled_ap_ids, local_only: local_only)

    notification_enabled_users =
      Enum.filter(potential_receivers, fn u -> u.ap_id in notification_enabled_ap_ids end)

    {notification_enabled_users, potential_receivers -- notification_enabled_users}
  end

  def get_notified_subscribers_from_activity(_, _), do: {[], []}

  # For some activities, only notify the author of the object
  def get_potential_receiver_ap_ids(%{data: %{"type" => type, "object" => object_id}})
      when type in ~w{Like Announce EmojiReact} do
    case Object.get_cached_by_ap_id(object_id) do
      %Object{data: %{"actor" => actor}} ->
        [actor]

      _ ->
        []
    end
  end

  def get_potential_receiver_ap_ids(%{data: %{"type" => "Follow", "object" => object_id}}) do
    [object_id]
  end

  def get_potential_receiver_ap_ids(%{data: %{"type" => "Flag", "actor" => actor}}) do
    (User.all_superusers() |> Enum.map(fn user -> user.ap_id end)) -- [actor]
  end

  def get_potential_receiver_ap_ids(activity) do
    []
    |> Utils.maybe_notify_to_recipients(activity)
    |> Utils.maybe_notify_mentioned_recipients(activity)
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

  def skip?(activity, user, opts \\ [])

  @spec skip?(Activity.t(), User.t(), Keyword.t()) :: boolean()
  def skip?(%Activity{} = activity, %User{} = user, opts) do
    [
      :self,
      :invisible,
      :block_from_strangers,
      :recently_followed,
      :filtered
    ]
    |> Enum.find(&skip?(&1, activity, user, opts))
  end

  def skip?(_activity, _user, _opts), do: false

  @spec skip?(atom(), Activity.t(), User.t(), Keyword.t()) :: boolean()
  def skip?(:self, %Activity{} = activity, %User{} = user, opts) do
    cond do
      opts[:type] == "poll" -> false
      activity.data["actor"] == user.ap_id -> true
      true -> false
    end
  end

  def skip?(:invisible, %Activity{} = activity, _user, _opts) do
    actor = activity.data["actor"]
    user = User.get_cached_by_ap_id(actor)
    User.invisible?(user)
  end

  def skip?(
        :block_from_strangers,
        %Activity{} = activity,
        %User{notification_settings: %{block_from_strangers: true}} = user,
        opts
      ) do
    actor = activity.data["actor"]
    follower = User.get_cached_by_ap_id(actor)

    cond do
      opts[:type] == "poll" -> false
      user.ap_id == actor -> false
      !User.following?(follower, user) -> true
      true -> false
    end
  end

  # To do: consider defining recency in hours and checking FollowingRelationship with a single SQL
  def skip?(
        :recently_followed,
        %Activity{data: %{"type" => "Follow"}} = activity,
        %User{} = user,
        _opts
      ) do
    actor = activity.data["actor"]

    Notification.for_user(user)
    |> Enum.any?(fn
      %{activity: %{data: %{"type" => "Follow", "actor" => ^actor}}} -> true
      _ -> false
    end)
  end

  def skip?(:filtered, %{data: %{"type" => type}}, _user, _opts) when type in ["Follow", "Move"],
    do: false

  def skip?(:filtered, activity, user, _opts) do
    object = Object.normalize(activity, fetch: false)

    cond do
      is_nil(object) ->
        false

      object.data["actor"] == user.ap_id ->
        false

      not is_nil(regex = Pleroma.Filter.compose_regex(user, :re)) ->
        Regex.match?(regex, object.data["content"])

      true ->
        false
    end
  end

  def skip?(_type, _activity, _user, _opts), do: false

  def mark_as_read?(activity, target_user) do
    user = Activity.user_actor(activity)
    User.mutes_user?(target_user, user) || CommonAPI.thread_muted?(target_user, activity)
  end

  def for_user_and_activity(user, activity) do
    from(n in __MODULE__,
      where: n.user_id == ^user.id,
      where: n.activity_id == ^activity.id
    )
    |> Repo.one()
  end

  @spec mark_context_as_read(User.t(), String.t()) :: {integer(), nil | [term()]}
  def mark_context_as_read(%User{id: id}, context) do
    from(
      n in Notification,
      join: a in assoc(n, :activity),
      where: n.user_id == ^id,
      where: n.seen == false,
      where: fragment("?->>'context'", a.data) == ^context
    )
    |> Repo.update_all(set: [seen: true])
  end
end
