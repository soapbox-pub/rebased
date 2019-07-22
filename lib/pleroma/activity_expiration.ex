# Pleroma: A lightweight social networking server
# Copyright © 2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ActivityExpiration do
  use Ecto.Schema

  alias Pleroma.Activity
  alias Pleroma.ActivityExpiration
  alias Pleroma.FlakeId
  alias Pleroma.Repo

  import Ecto.Query

  @type t :: %__MODULE__{}

  schema "activity_expirations" do
    belongs_to(:activity, Activity, type: FlakeId)
    field(:scheduled_at, :naive_datetime)
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
