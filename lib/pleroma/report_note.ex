# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ReportNote do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Pleroma.Activity
  alias Pleroma.Repo
  alias Pleroma.ReportNote
  alias Pleroma.User

  @type t :: %__MODULE__{}

  schema "report_notes" do
    field(:content, :string)
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    belongs_to(:activity, Activity, type: FlakeId.Ecto.CompatType)

    timestamps()
  end

  @spec create(FlakeId.Ecto.CompatType.t(), FlakeId.Ecto.CompatType.t(), String.t()) ::
          {:ok, ReportNote.t()} | {:error, Changeset.t()}
  def create(user_id, activity_id, content) do
    attrs = %{
      user_id: user_id,
      activity_id: activity_id,
      content: content
    }

    %ReportNote{}
    |> cast(attrs, [:user_id, :activity_id, :content])
    |> validate_required([:user_id, :activity_id, :content])
    |> Repo.insert()
  end

  @spec destroy(FlakeId.Ecto.CompatType.t()) ::
          {:ok, ReportNote.t()} | {:error, Changeset.t()}
  def destroy(id) do
    from(r in ReportNote, where: r.id == ^id)
    |> Repo.one()
    |> Repo.delete()
  end
end
