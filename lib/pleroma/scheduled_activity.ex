# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ScheduledActivity do
  use Ecto.Schema

  alias Pleroma.Repo
  alias Pleroma.ScheduledActivity
  alias Pleroma.User

  import Ecto.Query
  import Ecto.Changeset

  schema "scheduled_activities" do
    belongs_to(:user, User, type: Pleroma.FlakeId)
    field(:scheduled_at, :naive_datetime)
    field(:params, :map)

    timestamps()
  end

  def changeset(%ScheduledActivity{} = scheduled_activity, attrs) do
    scheduled_activity
    |> cast(attrs, [:scheduled_at, :params])
  end

  def update_changeset(%ScheduledActivity{} = scheduled_activity, attrs) do
    scheduled_activity
    |> cast(attrs, [:scheduled_at])
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

  def update(%User{} = user, scheduled_activity_id, attrs) do
    with %ScheduledActivity{} = scheduled_activity <- get(user, scheduled_activity_id) do
      scheduled_activity
      |> update_changeset(attrs)
      |> Repo.update()
    else
      nil -> {:error, :not_found}
    end
  end

  def delete(%User{} = user, scheduled_activity_id) do
    with %ScheduledActivity{} = scheduled_activity <- get(user, scheduled_activity_id) do
      scheduled_activity
      |> Repo.delete()
    else
      nil -> {:error, :not_found}
    end
  end

  def for_user_query(%User{} = user) do
    ScheduledActivity
    |> where(user_id: ^user.id)
  end
end
