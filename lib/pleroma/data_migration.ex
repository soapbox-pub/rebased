# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.DataMigration do
  use Ecto.Schema

  alias Pleroma.DataMigration
  alias Pleroma.DataMigration.State
  alias Pleroma.Repo

  import Ecto.Changeset

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

  def update(data_migration, params \\ %{}) do
    data_migration
    |> changeset(params)
    |> Repo.update()
  end

  def update_state(data_migration, new_state) do
    update(data_migration, %{state: new_state})
  end

  def get_by_name(name) do
    Repo.get_by(DataMigration, name: name)
  end

  def populate_hashtags_table, do: get_by_name("populate_hashtags_table")
end
