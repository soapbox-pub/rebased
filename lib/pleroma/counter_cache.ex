# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.CounterCache do
  alias Pleroma.CounterCache
  alias Pleroma.Repo
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "counter_cache" do
    field(:name, :string)
    field(:count, :integer)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name, :count])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end

  def get_as_map(names) when is_list(names) do
    CounterCache
    |> where([cc], cc.name in ^names)
    |> Repo.all()
    |> Enum.group_by(& &1.name, & &1.count)
    |> Map.new(fn {k, v} -> {k, hd(v)} end)
  end

  def set(name, count) do
    %CounterCache{}
    |> changeset(%{"name" => name, "count" => count})
    |> Repo.insert(
      on_conflict: [set: [count: count]],
      returning: true,
      conflict_target: :name
    )
  end
end
