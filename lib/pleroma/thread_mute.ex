# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ThreadMute do
  use Ecto.Schema

  alias Pleroma.Repo
  alias Pleroma.ThreadMute
  alias Pleroma.User

  require Ecto.Query

  schema "thread_mutes" do
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    field(:context, :string)
  end

  def changeset(mute, params \\ %{}) do
    mute
    |> Ecto.Changeset.cast(params, [:user_id, :context])
    |> Ecto.Changeset.foreign_key_constraint(:user_id)
    |> Ecto.Changeset.unique_constraint(:user_id, name: :unique_index)
  end

  def query(user_id, context) do
    {:ok, user_id} = FlakeId.Ecto.CompatType.dump(user_id)

    ThreadMute
    |> Ecto.Query.where(user_id: ^user_id)
    |> Ecto.Query.where(context: ^context)
  end

  def add_mute(user_id, context) do
    %ThreadMute{}
    |> changeset(%{user_id: user_id, context: context})
    |> Repo.insert()
  end

  def remove_mute(user_id, context) do
    query(user_id, context)
    |> Repo.delete_all()
  end

  def check_muted(user_id, context) do
    query(user_id, context)
    |> Repo.all()
  end
end
