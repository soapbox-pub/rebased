# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.UserNote do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.UserNote

  schema "user_notes" do
    belongs_to(:source, User, type: FlakeId.Ecto.CompatType)
    belongs_to(:target, User, type: FlakeId.Ecto.CompatType)
    field(:comment, :string)

    timestamps()
  end

  def changeset(%UserNote{} = user_note, params \\ %{}) do
    user_note
    |> cast(params, [:source_id, :target_id, :comment])
    |> validate_required([:source_id, :target_id])
  end

  def show(%User{} = source, %User{} = target) do
    with %UserNote{} = note <-
           UserNote
           |> where(source_id: ^source.id, target_id: ^target.id)
           |> Repo.one() do
      note.comment
    else
      _ -> ""
    end
  end

  def create(%User{} = source, %User{} = target, comment) do
    %UserNote{}
    |> changeset(%{
      source_id: source.id,
      target_id: target.id,
      comment: comment
    })
    |> Repo.insert(
      on_conflict: {:replace, [:comment]},
      conflict_target: [:source_id, :target_id]
    )
  end
end
