# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ScheduledActivity do
  use Ecto.Schema

  alias Pleroma.Config
  alias Pleroma.Repo
  alias Pleroma.ScheduledActivity
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI.Utils

  import Ecto.Query
  import Ecto.Changeset

  @min_offset :timer.minutes(5)

  schema "scheduled_activities" do
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    field(:scheduled_at, :naive_datetime)
    field(:params, :map)

    timestamps()
  end

  def changeset(%ScheduledActivity{} = scheduled_activity, attrs) do
    scheduled_activity
    |> cast(attrs, [:scheduled_at, :params])
    |> validate_required([:scheduled_at, :params])
    |> validate_scheduled_at()
    |> with_media_attachments()
  end

  defp with_media_attachments(
         %{changes: %{params: %{"media_ids" => media_ids} = params}} = changeset
       )
       when is_list(media_ids) do
    media_attachments = Utils.attachments_from_ids(%{"media_ids" => media_ids})

    params =
      params
      |> Map.put("media_attachments", media_attachments)
      |> Map.put("media_ids", media_ids)

    put_change(changeset, :params, params)
  end

  defp with_media_attachments(changeset), do: changeset

  def update_changeset(%ScheduledActivity{} = scheduled_activity, attrs) do
    scheduled_activity
    |> cast(attrs, [:scheduled_at])
    |> validate_required([:scheduled_at])
    |> validate_scheduled_at()
  end

  def validate_scheduled_at(changeset) do
    validate_change(changeset, :scheduled_at, fn _, scheduled_at ->
      cond do
        not far_enough?(scheduled_at) ->
          [scheduled_at: "must be at least 5 minutes from now"]

        exceeds_daily_user_limit?(changeset.data.user_id, scheduled_at) ->
          [scheduled_at: "daily limit exceeded"]

        exceeds_total_user_limit?(changeset.data.user_id) ->
          [scheduled_at: "total limit exceeded"]

        true ->
          []
      end
    end)
  end

  def exceeds_daily_user_limit?(user_id, scheduled_at) do
    ScheduledActivity
    |> where(user_id: ^user_id)
    |> where([sa], type(sa.scheduled_at, :date) == type(^scheduled_at, :date))
    |> select([sa], count(sa.id))
    |> Repo.one()
    |> Kernel.>=(Config.get([ScheduledActivity, :daily_user_limit]))
  end

  def exceeds_total_user_limit?(user_id) do
    ScheduledActivity
    |> where(user_id: ^user_id)
    |> select([sa], count(sa.id))
    |> Repo.one()
    |> Kernel.>=(Config.get([ScheduledActivity, :total_user_limit]))
  end

  def far_enough?(scheduled_at) when is_binary(scheduled_at) do
    with {:ok, scheduled_at} <- Ecto.Type.cast(:naive_datetime, scheduled_at) do
      far_enough?(scheduled_at)
    else
      _ -> false
    end
  end

  def far_enough?(scheduled_at) do
    now = NaiveDateTime.utc_now()
    diff = NaiveDateTime.diff(scheduled_at, now, :millisecond)
    diff > @min_offset
  end

  def new(%User{} = user, attrs) do
    %ScheduledActivity{user_id: user.id}
    |> changeset(attrs)
  end

  def create(%User{} = user, attrs) do
    user
    |> new(attrs)
    |> Repo.insert()
  end

  def get(%User{} = user, scheduled_activity_id) do
    ScheduledActivity
    |> where(user_id: ^user.id)
    |> where(id: ^scheduled_activity_id)
    |> Repo.one()
  end

  def update(%ScheduledActivity{} = scheduled_activity, attrs) do
    scheduled_activity
    |> update_changeset(attrs)
    |> Repo.update()
  end

  def delete(%ScheduledActivity{} = scheduled_activity) do
    scheduled_activity
    |> Repo.delete()
  end

  def delete(id) when is_binary(id) or is_integer(id) do
    ScheduledActivity
    |> where(id: ^id)
    |> select([sa], sa)
    |> Repo.delete_all()
    |> case do
      {1, [scheduled_activity]} -> {:ok, scheduled_activity}
      _ -> :error
    end
  end

  def for_user_query(%User{} = user) do
    ScheduledActivity
    |> where(user_id: ^user.id)
  end

  def due_activities(offset \\ 0) do
    naive_datetime =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(offset, :millisecond)

    ScheduledActivity
    |> where([sa], sa.scheduled_at < ^naive_datetime)
    |> Repo.all()
  end
end
