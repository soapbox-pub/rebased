# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Hashtag do
  use Ecto.Schema

  import Ecto.Changeset

  alias Pleroma.Hashtag
  alias Pleroma.Repo

  schema "hashtags" do
    field(:name, :string)

    many_to_many(:objects, Pleroma.Object, join_through: "hashtags_objects", on_replace: :delete)

    timestamps()
  end

  def get_by_name(name) do
    Repo.get_by(Hashtag, name: name)
  end

  def get_or_create_by_name(name) when is_bitstring(name) do
    with %Hashtag{} = hashtag <- get_by_name(name) do
      {:ok, hashtag}
    else
      _ ->
        %Hashtag{}
        |> changeset(%{name: name})
        |> Repo.insert()
    end
  end

  def get_or_create_by_names(names) when is_list(names) do
    Enum.reduce_while(names, {:ok, []}, fn name, {:ok, list} ->
      case get_or_create_by_name(name) do
        {:ok, %Hashtag{} = hashtag} ->
          {:cont, {:ok, list ++ [hashtag]}}

        error ->
          {:halt, error}
      end
    end)
  end

  def changeset(%Hashtag{} = struct, params) do
    struct
    |> cast(params, [:name])
    |> update_change(:name, &String.downcase/1)
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
