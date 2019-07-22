# Pleroma: A lightweight social networking server
# Copyright © 2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ActivityExpiration do
  use Ecto.Schema

  alias Pleroma.Activity
  alias Pleroma.ActivityExpiration
  alias Pleroma.FlakeId
  alias Pleroma.Repo

  import Ecto.Changeset
  import Ecto.Query

  @type t :: %__MODULE__{}

  schema "activity_expirations" do
    belongs_to(:activity, Activity, type: FlakeId)
    field(:scheduled_at, :naive_datetime)
  end

  def changeset(%ActivityExpiration{} = expiration, attrs) do
    expiration
    |> cast(attrs, [:scheduled_at])
    |> validate_required([:scheduled_at])
  end

  def get_by_activity_id(activity_id) do
    ActivityExpiration
    |> where([exp], exp.activity_id == ^activity_id)
    |> Repo.one()
  end

  def create(%Activity{} = activity, scheduled_at) do
    %ActivityExpiration{activity_id: activity.id}
    |> changeset(%{scheduled_at: scheduled_at})
    |> Repo.insert()
  end

  def due_expirations(offset \\ 0) do
    naive_datetime =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(offset, :millisecond)

    ActivityExpiration
    |> where([exp], exp.scheduled_at < ^naive_datetime)
    |> Repo.all()
  end
end
