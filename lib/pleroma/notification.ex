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
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils

  import Ecto.Query
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "notifications" do
    field(:seen, :boolean, default: false)
    belongs_to(:user, User, type: Pleroma.FlakeId)
    belongs_to(:activity, Activity, type: Pleroma.FlakeId)

    timestamps()
  end

  def changeset(%Notification{} = notification, attrs) do
    notification
    |> cast(attrs, [:seen])
  end

  def for_user_query(user) do
    Notification
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
  end

  def for_user(user, opts \\ %{}) do
    user
    |> for_user_query()
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
        update: [
          set: [
            seen: true,
            updated_at: ^NaiveDateTime.utc_now()
          ]
        ]
      )

    Repo.update_all(query, [])
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

  def create_notifications(%Activity{data: %{"to" => _, "type" => type}} = activity)
      when type in ["Create", "Like", "Announce", "Follow"] do
    users = get_notified_from_activity(activity)

    notifications = Enum.map(users, fn user -> create_notification(activity, user) end)
    {:ok, notifications}
  end

  def create_notifications(_), do: {:ok, []}

  # TODO move to sql, too.
  def create_notification(%Activity{} = activity, %User{} = user) do
    unless skip?(activity, user) do
      notification = %Notification{user_id: user.id, activity: activity}
      {:ok, notification} = Repo.insert(notification)
      Pleroma.Web.Streamer.stream("user", notification)
      Pleroma.Web.Push.send(notification)
      notification
    end
  end

  def get_notified_from_activity(activity, local_only \\ true)

  def get_notified_from_activity(
        %Activity{data: %{"to" => _, "type" => type} = _data} = activity,
        local_only
      )
      when type in ["Create", "Like", "Announce", "Follow"] do
    recipients =
      []
      |> Utils.maybe_notify_to_recipients(activity)
      |> Utils.maybe_notify_mentioned_recipients(activity)
      |> Utils.maybe_notify_subscribers(activity)
      |> Enum.uniq()

    User.get_users_from_set(recipients, local_only)
  end

  def get_notified_from_activity(_, _local_only), do: []

  def skip?(activity, user) do
    [:self, :blocked, :local, :muted, :followers, :follows, :recently_followed]
    |> Enum.any?(&skip?(&1, activity, user))
  end

  def skip?(:self, activity, user) do
    activity.data["actor"] == user.ap_id
  end

  def skip?(:blocked, activity, user) do
    actor = activity.data["actor"]
    User.blocks?(user, %{ap_id: actor})
  end

  def skip?(:local, %{local: true}, %{info: %{notification_settings: %{"local" => false}}}),
    do: true

  def skip?(:local, %{local: false}, %{info: %{notification_settings: %{"remote" => false}}}),
    do: true

  def skip?(:muted, activity, user) do
    actor = activity.data["actor"]

    User.mutes?(user, %{ap_id: actor}) or CommonAPI.thread_muted?(user, activity)
  end

  def skip?(
        :followers,
        activity,
        %{info: %{notification_settings: %{"followers" => false}}} = user
      ) do
    actor = activity.data["actor"]
    follower = User.get_cached_by_ap_id(actor)
    User.following?(follower, user)
  end

  def skip?(:follows, activity, %{info: %{notification_settings: %{"follows" => false}}} = user) do
    actor = activity.data["actor"]
    followed = User.get_cached_by_ap_id(actor)
    User.following?(user, followed)
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
