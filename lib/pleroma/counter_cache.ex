# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.CounterCache do
  alias Pleroma.CounterCache
  alias Pleroma.Repo
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "counter_cache" do
    field(:instance, :string)
    field(:public, :integer)
    field(:unlisted, :integer)
    field(:private, :integer)
    field(:direct, :integer)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:instance, :public, :unlisted, :private, :direct])
    |> validate_required([:instance])
    |> unique_constraint(:instance)
  end

  def get_by_instance(instance) do
    CounterCache
    |> select([c], %{
      "public" => c.public,
      "unlisted" => c.unlisted,
      "private" => c.private,
      "direct" => c.direct
    })
    |> where([c], c.instance == ^instance)
    |> Repo.one()
    |> case do
      nil -> %{"public" => 0, "unlisted" => 0, "private" => 0, "direct" => 0}
      val -> val
    end
  end

  def get_sum do
    CounterCache
    |> select([c], %{
      "public" => type(sum(c.public), :integer),
      "unlisted" => type(sum(c.unlisted), :integer),
      "private" => type(sum(c.private), :integer),
      "direct" => type(sum(c.direct), :integer)
    })
    |> Repo.one()
  end

  def set(instance, values) do
    params =
      Enum.reduce(
        ["public", "private", "unlisted", "direct"],
        %{"instance" => instance},
        fn param, acc ->
          Map.put_new(acc, param, Map.get(values, param, 0))
        end
      )

    %CounterCache{}
    |> changeset(params)
    |> Repo.insert(
      on_conflict: [
        set: [
          public: params["public"],
          private: params["private"],
          unlisted: params["unlisted"],
          direct: params["direct"]
        ]
      ],
      returning: true,
      conflict_target: :instance
    )
  end
end
