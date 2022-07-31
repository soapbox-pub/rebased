# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.AnnouncementReadRelationship do
  use Ecto.Schema

  import Ecto.Changeset

  alias FlakeId.Ecto.CompatType
  alias Pleroma.Announcement
  alias Pleroma.Repo
  alias Pleroma.User

  @type t :: %__MODULE__{}

  schema "announcement_read_relationships" do
    belongs_to(:user, User, type: CompatType)
    belongs_to(:announcement, Announcement, type: CompatType)

    timestamps(updated_at: false)
  end

  def mark_read(user, announcement) do
    %__MODULE__{}
    |> cast(%{user_id: user.id, announcement_id: announcement.id}, [:user_id, :announcement_id])
    |> validate_required([:user_id, :announcement_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:announcement_id)
    |> unique_constraint([:user_id, :announcement_id])
    |> Repo.insert()
  end

  def mark_unread(user, announcement) do
    with relationship <- get(user, announcement),
         {:exists, true} <- {:exists, not is_nil(relationship)},
         {:ok, _} <- Repo.delete(relationship) do
      :ok
    else
      {:exists, false} ->
        :ok

      _ ->
        :error
    end
  end

  def get(user, announcement) do
    Repo.get_by(__MODULE__, user_id: user.id, announcement_id: announcement.id)
  end

  def exists?(user, announcement) do
    not is_nil(get(user, announcement))
  end
end
