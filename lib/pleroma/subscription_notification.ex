# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.SubscriptionNotification do
  use Ecto.Schema

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Pagination
  alias Pleroma.Repo
  alias Pleroma.SubscriptionNotification
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.Push
  alias Pleroma.Web.Streamer

  import Ecto.Query
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "subscription_notifications" do
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    belongs_to(:activity, Activity, type: FlakeId.Ecto.CompatType)

    timestamps()
  end

  def changeset(%SubscriptionNotification{} = notification, attrs) do
    cast(notification, attrs, [])
  end

  def for_user_query(user, opts \\ []) do
    query =
      SubscriptionNotification
      |> where(user_id: ^user.id)
      |> where(
        [n, a],
        fragment(
          "? not in (SELECT ap_id FROM users WHERE info->'deactivated' @> 'true')",
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

    if opts[:with_muted] do
      query
    else
      query
      |> where([n, a], a.actor not in ^user.info.muted_notifications)
      |> where([n, a], a.actor not in ^user.info.blocks)
      |> where(
        [n, a],
        fragment("substring(? from '.*://([^/]*)')", a.actor) not in ^user.info.domain_blocks
      )
      |> join(:left, [n, a], tm in Pleroma.ThreadMute,
        on: tm.user_id == ^user.id and tm.context == fragment("?->>'context'", a.data)
      )
      |> where([n, a, o, tm], is_nil(tm.user_id))
    end
  end

  def for_user(user, opts \\ %{}) do
    user
    |> for_user_query(opts)
    |> Pagination.fetch_paginated(opts)
  end

  @doc """
  Returns notifications for user received since given date.

  ## Examples

      iex> Pleroma.SubscriptionNotification.for_user_since(%Pleroma.User{}, ~N[2019-04-13 11:22:33])
      [%Pleroma.SubscriptionNotification{}, %Pleroma.SubscriptionNotification{}]

      iex> Pleroma.SubscriptionNotification.for_user_since(%Pleroma.User{}, ~N[2019-04-15 11:22:33])
      []
  """
  @spec for_user_since(Pleroma.User.t(), NaiveDateTime.t()) :: [t()]
  def for_user_since(user, date) do
    user
    |> for_user_query()
    |> where([n], n.updated_at > ^date)
    |> Repo.all()
  end

  def clear_up_to(%{id: user_id} = _user, id) do
    from(
      n in SubscriptionNotification,
      where: n.user_id == ^user_id,
      where: n.id <= ^id
    )
    |> Repo.delete_all([])
  end

  def get(%{id: user_id} = _user, id) do
    query =
      from(
        n in SubscriptionNotification,
        where: n.id == ^id,
        join: activity in assoc(n, :activity),
        preload: [activity: activity]
      )

    case Repo.one(query) do
      %{user_id: ^user_id} = notification ->
        {:ok, notification}

      _ ->
        {:error, "Cannot get notification"}
    end
  end

  def clear(user) do
    from(n in SubscriptionNotification, where: n.user_id == ^user.id)
    |> Repo.delete_all()
  end

  def destroy_multiple(%{id: user_id} = _user, ids) do
    from(n in SubscriptionNotification,
      where: n.id in ^ids,
      where: n.user_id == ^user_id
    )
    |> Repo.delete_all()
  end

  def dismiss(%{id: user_id} = _user, id) do
    case Repo.get(SubscriptionNotification, id) do
      %{user_id: ^user_id} = notification ->
        Repo.delete(notification)

      _ ->
        {:error, "Cannot dismiss notification"}
    end
  end

  def create_notifications(%Activity{data: %{"to" => _, "type" => "Create"}} = activity) do
    case Object.normalize(activity) do
      %{data: %{"type" => "Answer"}} ->
        {:ok, []}

      _ ->
        users = get_notified_from_activity(activity)
        notifications = Enum.map(users, fn user -> create_notification(activity, user) end)
        {:ok, notifications}
    end
  end

  def create_notifications(%Activity{data: %{"to" => _, "type" => type}} = activity)
      when type in ["Like", "Announce", "Follow"] do
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
      notification = %SubscriptionNotification{user_id: user.id, activity: activity}
      {:ok, notification} = Repo.insert(notification)
      Streamer.stream("user", notification)
      Streamer.stream("user:subscription_notification", notification)
      Push.send(notification)
      notification
    end
  end

  def get_notified_from_activity(activity, local_only \\ true)

  def get_notified_from_activity(
        %Activity{data: %{"to" => _, "type" => type} = _data} = activity,
        local_only
      )
      when type in ["Create", "Like", "Announce", "Follow"] do
    []
    |> Utils.maybe_notify_subscribers(activity)
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
        %{data: %{"actor" => actor}},
        %{info: %{notification_settings: %{"followers" => false}}} = user
      ) do
    actor
    |> User.get_cached_by_ap_id()
    |> User.following?(user)
  end

  def skip?(
        :non_followers,
        activity,
        %{info: %{notification_settings: %{"non_followers" => false}}} = user
      ) do
    actor = activity.data["actor"]
    follower = User.get_cached_by_ap_id(actor)
    !User.following?(follower, user)
  end

  def skip?(:follows, activity, %{info: %{notification_settings: %{"follows" => false}}} = user) do
    actor = activity.data["actor"]
    followed = User.get_cached_by_ap_id(actor)
    User.following?(user, followed)
  end

  def skip?(
        :non_follows,
        activity,
        %{info: %{notification_settings: %{"non_follows" => false}}} = user
      ) do
    actor = activity.data["actor"]
    followed = User.get_cached_by_ap_id(actor)
    !User.following?(user, followed)
  end

  def skip?(:recently_followed, %{data: %{"type" => "Follow", "actor" => actor}}, user) do
    user
    |> SubscriptionNotification.for_user()
    |> Enum.any?(&match?(%{activity: %{data: %{"type" => "Follow", "actor" => ^actor}}}, &1))
  end

  def skip?(_, _, _), do: false
end
