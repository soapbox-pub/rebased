# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Bookmark do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Pleroma.Activity
  alias Pleroma.Bookmark
  alias Pleroma.Repo
  alias Pleroma.User

  @type t :: %__MODULE__{}

  schema "bookmarks" do
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    belongs_to(:activity, Activity, type: FlakeId.Ecto.CompatType)

    timestamps()
  end

  @spec create(FlakeId.Ecto.CompatType.t(), FlakeId.Ecto.CompatType.t()) ::
          {:ok, Bookmark.t()} | {:error, Changeset.t()}
  def create(user_id, activity_id) do
    attrs = %{
      user_id: user_id,
      activity_id: activity_id
    }

    %Bookmark{}
    |> cast(attrs, [:user_id, :activity_id])
    |> validate_required([:user_id, :activity_id])
    |> unique_constraint(:activity_id, name: :bookmarks_user_id_activity_id_index)
    |> Repo.insert()
  end

  @spec for_user_query(FlakeId.Ecto.CompatType.t()) :: Ecto.Query.t()
  def for_user_query(user_id) do
    Bookmark
    |> where(user_id: ^user_id)
    |> join(:inner, [b], activity in assoc(b, :activity))
    |> preload([b, a], activity: a)
  end

  def get(user_id, activity_id) do
    Bookmark
    |> where(user_id: ^user_id)
    |> where(activity_id: ^activity_id)
    |> Repo.one()
  end

  @spec destroy(FlakeId.Ecto.CompatType.t(), FlakeId.Ecto.CompatType.t()) ::
          {:ok, Bookmark.t()} | {:error, Changeset.t()}
  def destroy(user_id, activity_id) do
    from(b in Bookmark,
      where: b.user_id == ^user_id,
      where: b.activity_id == ^activity_id
    )
    |> Repo.one()
    |> Repo.delete()
  end
end
