# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.UserMute do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.UserMute

  schema "user_mutes" do
    belongs_to(:muter, User, type: FlakeId.Ecto.CompatType)
    belongs_to(:mutee, User, type: FlakeId.Ecto.CompatType)

    timestamps(updated_at: false)
  end

  def changeset(%UserMute{} = user_mute, params \\ %{}) do
    user_mute
    |> cast(params, [:muter_id, :mutee_id])
    |> validate_required([:muter_id, :mutee_id])
    |> unique_constraint(:mutee_id, name: :user_mutes_muter_id_mutee_id_index)
    |> validate_not_self_mute()
  end

  def exists?(%User{} = muter, %User{} = mutee) do
    UserMute
    |> where(muter_id: ^muter.id, mutee_id: ^mutee.id)
    |> Repo.exists?()
  end

  def create(%User{} = muter, %User{} = mutee) do
    %UserMute{}
    |> changeset(%{muter_id: muter.id, mutee_id: mutee.id})
    |> Repo.insert(
      on_conflict: :replace_all_except_primary_key,
      conflict_target: [:muter_id, :mutee_id]
    )
  end

  def delete(%User{} = muter, %User{} = mutee) do
    attrs = %{muter_id: muter.id, mutee_id: mutee.id}

    case Repo.get_by(UserMute, attrs) do
      %UserMute{} = existing_record -> Repo.delete(existing_record)
      nil -> {:ok, nil}
    end
  end

  defp validate_not_self_mute(%Ecto.Changeset{} = changeset) do
    changeset
    |> validate_change(:mutee_id, fn _, mutee_id ->
      if mutee_id == get_field(changeset, :muter_id) do
        [mutee_id: "can't be equal to muter_id"]
      else
        []
      end
    end)
    |> validate_change(:muter_id, fn _, muter_id ->
      if muter_id == get_field(changeset, :mutee_id) do
        [muter_id: "can't be equal to mutee_id"]
      else
        []
      end
    end)
  end
end
