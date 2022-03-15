# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Rule do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Pleroma.Repo
  alias Pleroma.Rule

  schema "rules" do
    field(:priority, :integer, default: 0)
    field(:text, :string)

    timestamps()
  end

  def changeset(%Rule{} = rule, params \\ %{}) do
    rule
    |> cast(params, [:priority, :text])
    |> validate_required([:text])
  end

  def query do
    Rule
    |> order_by(asc: :priority)
    |> order_by(asc: :id)
  end

  def get(ids) when is_list(ids) do
    from(r in __MODULE__, where: r.id in ^ids)
    |> Repo.all()
  end

  def get(id), do: Repo.get(__MODULE__, id)

  def create(params) do
    {:ok, rule} =
      %Rule{}
      |> changeset(params)
      |> Repo.insert()

    rule
  end

  def update(params, id) do
    {:ok, rule} =
      get(id)
      |> changeset(params)
      |> Repo.update()

    rule
  end

  def delete(id) do
    get(id)
    |> Repo.delete()
  end
end
