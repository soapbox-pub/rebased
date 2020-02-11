# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ScheduledActivity do
  use Ecto.Schema

  alias Ecto.Multi
  alias Pleroma.Config
  alias Pleroma.Repo
  alias Pleroma.ScheduledActivity
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Workers.ScheduledActivityWorker

  import Ecto.Query
  import Ecto.Changeset

  @type t :: %__MODULE__{}

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
    changeset(%ScheduledActivity{user_id: user.id}, attrs)
  end

  @doc """
  Creates ScheduledActivity and add to queue to perform at scheduled_at date
  """
  @spec create(User.t(), map()) :: {:ok, ScheduledActivity.t()} | {:error, Ecto.Changeset.t()}
  def create(%User{} = user, attrs) do
    Multi.new()
    |> Multi.insert(:scheduled_activity, new(user, attrs))
    |> maybe_add_jobs(Config.get([ScheduledActivity, :enabled]))
    |> Repo.transaction()
    |> transaction_response
  end

  defp maybe_add_jobs(multi, true) do
    multi
    |> Multi.run(:scheduled_activity_job, fn _repo, %{scheduled_activity: activity} ->
      %{activity_id: activity.id}
      |> ScheduledActivityWorker.new(scheduled_at: activity.scheduled_at)
      |> Oban.insert()
    end)
  end

  defp maybe_add_jobs(multi, _), do: multi

  def get(%User{} = user, scheduled_activity_id) do
    ScheduledActivity
    |> where(user_id: ^user.id)
    |> where(id: ^scheduled_activity_id)
    |> Repo.one()
  end

  @spec update(ScheduledActivity.t(), map()) ::
          {:ok, ScheduledActivity.t()} | {:error, Ecto.Changeset.t()}
  def update(%ScheduledActivity{id: id} = scheduled_activity, attrs) do
    with {:error, %Ecto.Changeset{valid?: true} = changeset} <-
           {:error, update_changeset(scheduled_activity, attrs)} do
      Multi.new()
      |> Multi.update(:scheduled_activity, changeset)
      |> Multi.update_all(:scheduled_job, job_query(id),
        set: [scheduled_at: get_field(changeset, :scheduled_at)]
      )
      |> Repo.transaction()
      |> transaction_response
    end
  end

  @doc "Deletes a ScheduledActivity and linked jobs."
  @spec delete(ScheduledActivity.t() | binary() | integer) ::
          {:ok, ScheduledActivity.t()} | {:error, Ecto.Changeset.t()}
  def delete(%ScheduledActivity{id: id} = scheduled_activity) do
    Multi.new()
    |> Multi.delete(:scheduled_activity, scheduled_activity, stale_error_field: :id)
    |> Multi.delete_all(:jobs, job_query(id))
    |> Repo.transaction()
    |> transaction_response
  end

  def delete(id) when is_binary(id) or is_integer(id) do
    delete(%__MODULE__{id: id})
  end

  defp transaction_response(result) do
    case result do
      {:ok, %{scheduled_activity: scheduled_activity}} ->
        {:ok, scheduled_activity}

      {:error, _, changeset, _} ->
        {:error, changeset}
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

  def job_query(scheduled_activity_id) do
    from(j in Oban.Job,
      where: j.queue == "scheduled_activities",
      where: fragment("args ->> 'activity_id' = ?::text", ^to_string(scheduled_activity_id))
    )
  end
end
