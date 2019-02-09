# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ThreadMute do
  use Ecto.Schema
  alias Pleroma.Web.ThreadMute
  alias Pleroma.{Activity, Repo, User}
  require Ecto.Query

  schema "thread_mutes" do
    belongs_to(:user, User, type: Pleroma.FlakeId)
    field(:context, :string)
  end

  def changeset(mute, params \\ %{}) do
    mute
    |> Ecto.Changeset.cast(params, [:user_id, :context])
    |> Ecto.Changeset.foreign_key_constraint(:user_id)
    |> Ecto.Changeset.unique_constraint(:user_id, name: :unique_index)
  end

  def add_mute(user, id) do
    activity = Activity.get_by_id(id)
    context = activity.data["context"]
    changeset = changeset(%Pleroma.Web.ThreadMute{}, %{user_id: user.id, context: context})

    case Repo.insert(changeset) do
      {:ok, _} -> {:ok, activity}
      {:error, _} -> {:error, "conversation is already muted"}
    end
  end

  def remove_mute(user, id) do
    user_id = Pleroma.FlakeId.from_string(user.id)
    activity = Activity.get_by_id(id)
    context = activity.data["context"]

    Ecto.Query.from(m in ThreadMute, where: m.user_id == ^user_id and m.context == ^context)
    |> Repo.delete_all()

    {:ok, activity}
  end

  def muted?(user, activity) do
    user_id = Pleroma.FlakeId.from_string(user.id)
    context = activity.data["context"]

    result =
      Ecto.Query.from(m in ThreadMute,
        where: m.user_id == ^user_id and m.context == ^context
      )
      |> Repo.all()

    case result do
      [] -> false
      _ -> true
    end
  end
end
