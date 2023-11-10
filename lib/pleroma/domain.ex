# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Pleroma.Domain do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Pleroma.Repo

  schema "domains" do
    field(:domain, :string, default: "")
    field(:public, :boolean, default: false)

    timestamps()
  end

  def changeset(%__MODULE__{} = domain, params \\ %{}) do
    domain
    |> cast(params, [:domain, :public])
    |> validate_required([:domain])
    |> update_change(:domain, &String.downcase/1)
    |> unique_constraint(:domain)
  end

  def update_changeset(%__MODULE__{} = domain, params \\ %{}) do
    domain
    |> cast(params, [:public])
  end

  def list do
    __MODULE__
    |> order_by(asc: :id)
    |> Repo.all()
  end

  def get(id), do: Repo.get(__MODULE__, id)

  def create(params) do
    %__MODULE__{}
    |> changeset(params)
    |> Repo.insert()
  end

  def update(params, id) do
    get(id)
    |> update_changeset(params)
    |> Repo.update()
  end

  def delete(id) do
    get(id)
    |> Repo.delete()
  end
end
