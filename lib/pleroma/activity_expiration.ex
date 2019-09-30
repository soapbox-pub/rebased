# Pleroma: A lightweight social networking server
# Copyright © 2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ActivityExpiration do
  use Ecto.Schema

  alias Pleroma.Activity
  alias Pleroma.ActivityExpiration
  alias Pleroma.Repo

  import Ecto.Changeset
  import Ecto.Query

  @type t :: %__MODULE__{}
  @min_activity_lifetime :timer.hours(1)

  schema "activity_expirations" do
    belongs_to(:activity, Activity, type: FlakeId.Ecto.CompatType)
    field(:scheduled_at, :naive_datetime)
  end

  def changeset(%ActivityExpiration{} = expiration, attrs) do
    expiration
    |> cast(attrs, [:scheduled_at])
    |> validate_required([:scheduled_at])
    |> validate_scheduled_at()
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

  def validate_scheduled_at(changeset) do
    validate_change(changeset, :scheduled_at, fn _, scheduled_at ->
      if not expires_late_enough?(scheduled_at) do
        [scheduled_at: "an ephemeral activity must live for at least one hour"]
      else
        []
      end
    end)
  end

  def expires_late_enough?(scheduled_at) do
    now = NaiveDateTime.utc_now()
    diff = NaiveDateTime.diff(scheduled_at, now, :millisecond)
    diff >= @min_activity_lifetime
  end
end
