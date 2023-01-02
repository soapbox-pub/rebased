# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.DataMigration do
  use Ecto.Schema

  alias Pleroma.DataMigration
  alias Pleroma.DataMigration.State
  alias Pleroma.Repo

  import Ecto.Changeset
  import Ecto.Query

  schema "data_migrations" do
    field(:name, :string)
    field(:state, State, default: :pending)
    field(:feature_lock, :boolean, default: false)
    field(:params, :map, default: %{})
    field(:data, :map, default: %{})

    timestamps()
  end

  def changeset(data_migration, params \\ %{}) do
    data_migration
    |> cast(params, [:name, :state, :feature_lock, :params, :data])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end

  def update_one_by_id(id, params \\ %{}) do
    with {1, _} <-
           from(dm in DataMigration, where: dm.id == ^id)
           |> Repo.update_all(set: params) do
      :ok
    end
  end

  def get_by_name(name) do
    Repo.get_by(DataMigration, name: name)
  end

  def populate_hashtags_table, do: get_by_name("populate_hashtags_table")
  def delete_context_objects, do: get_by_name("delete_context_objects")
end
