# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Bookmark do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Pleroma.Activity
  alias Pleroma.Bookmark
  alias Pleroma.BookmarkFolder
  alias Pleroma.Repo
  alias Pleroma.User

  @type t :: %__MODULE__{}

  schema "bookmarks" do
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    belongs_to(:activity, Activity, type: FlakeId.Ecto.CompatType)
    belongs_to(:folder, BookmarkFolder, type: FlakeId.Ecto.CompatType)

    timestamps()
  end

  @spec create(Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, Bookmark.t()} | {:error, Ecto.Changeset.t()}
  def create(user_id, activity_id, folder_id \\ nil) do
    attrs = %{
      user_id: user_id,
      activity_id: activity_id,
      folder_id: folder_id
    }

    %Bookmark{}
    |> cast(attrs, [:user_id, :activity_id, :folder_id])
    |> validate_required([:user_id, :activity_id])
    |> unique_constraint(:activity_id, name: :bookmarks_user_id_activity_id_index)
    |> Repo.insert(
      on_conflict: [set: [folder_id: folder_id]],
      conflict_target: [:user_id, :activity_id]
    )
  end

  @spec for_user_query(Ecto.UUID.t()) :: Ecto.Query.t()
  def for_user_query(user_id, folder_id \\ nil) do
    Bookmark
    |> where(user_id: ^user_id)
    |> maybe_filter_by_folder(folder_id)
    |> join(:inner, [b], activity in assoc(b, :activity))
    |> preload([b, a], activity: a)
  end

  defp maybe_filter_by_folder(query, nil), do: query

  defp maybe_filter_by_folder(query, folder_id) do
    query
    |> where(folder_id: ^folder_id)
  end

  def get(user_id, activity_id) do
    Bookmark
    |> where(user_id: ^user_id)
    |> where(activity_id: ^activity_id)
    |> Repo.one()
  end

  @spec destroy(Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, Bookmark.t()} | {:error, Ecto.Changeset.t()}
  def destroy(user_id, activity_id) do
    from(b in Bookmark,
      where: b.user_id == ^user_id,
      where: b.activity_id == ^activity_id
    )
    |> Repo.one()
    |> Repo.delete()
  end

  def set_folder(bookmark, folder_id) do
    bookmark
    |> cast(%{folder_id: folder_id}, [:folder_id])
    |> validate_required([:folder_id])
    |> Repo.update()
  end
end
