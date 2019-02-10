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

  def query(user, context) do
    user_id = Pleroma.FlakeId.from_string(user.id)

    ThreadMute
    |> Ecto.Query.where(user_id: ^user_id)
    |> Ecto.Query.where(context: ^context)
  end

  def add_mute(user, id) do
    activity = Activity.get_by_id(id)

    with changeset <-
           changeset(%ThreadMute{}, %{user_id: user.id, context: activity.data["context"]}),
         {:ok, _} <- Repo.insert(changeset) do
      {:ok, activity}
    else
      {:error, _} -> {:error, "conversation is already muted"}
    end
  end

  def remove_mute(user, id) do
    activity = Activity.get_by_id(id)

    query(user, activity.data["context"])
    |> Repo.delete_all()

    {:ok, activity}
  end

  def muted?(%{id: nil} = _user, _), do: false

  def muted?(user, activity) do
    with query <- query(user, activity.data["context"]),
         [] <- Repo.all(query) do
      false
    else
      _ -> true
    end
  end
end
