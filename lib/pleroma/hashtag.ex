# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Hashtag do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Ecto.Multi
  alias Pleroma.Hashtag
  alias Pleroma.Object
  alias Pleroma.Repo

  schema "hashtags" do
    field(:name, :string)

    many_to_many(:objects, Object, join_through: "hashtags_objects", on_replace: :delete)

    timestamps()
  end

  def normalize_name(name) do
    name
    |> String.downcase()
    |> String.trim()
  end

  def get_or_create_by_name(name) do
    changeset = changeset(%Hashtag{}, %{name: name})

    Repo.insert(
      changeset,
      on_conflict: [set: [name: get_field(changeset, :name)]],
      conflict_target: :name,
      returning: true
    )
  end

  def get_or_create_by_names(names) when is_list(names) do
    names = Enum.map(names, &normalize_name/1)
    timestamp = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    structs =
      Enum.map(names, fn name ->
        %Hashtag{}
        |> changeset(%{name: name})
        |> Map.get(:changes)
        |> Map.merge(%{inserted_at: timestamp, updated_at: timestamp})
      end)

    try do
      with {:ok, %{query_op: hashtags}} <-
             Multi.new()
             |> Multi.insert_all(:insert_all_op, Hashtag, structs,
               on_conflict: :nothing,
               conflict_target: :name
             )
             |> Multi.run(:query_op, fn _repo, _changes ->
               {:ok, Repo.all(from(ht in Hashtag, where: ht.name in ^names))}
             end)
             |> Repo.transaction() do
        {:ok, hashtags}
      else
        {:error, _name, value, _changes_so_far} -> {:error, value}
      end
    rescue
      e -> {:error, e}
    end
  end

  def changeset(%Hashtag{} = struct, params) do
    struct
    |> cast(params, [:name])
    |> update_change(:name, &normalize_name/1)
    |> validate_required([:name])
    |> unique_constraint(:name)
  end

  def unlink(%Object{id: object_id}) do
    with {_, hashtag_ids} <-
           from(hto in "hashtags_objects",
             where: hto.object_id == ^object_id,
             select: hto.hashtag_id
           )
           |> Repo.delete_all(),
         {:ok, unreferenced_count} <- delete_unreferenced(hashtag_ids) do
      {:ok, length(hashtag_ids), unreferenced_count}
    end
  end

  @delete_unreferenced_query """
  DELETE FROM hashtags WHERE id IN
    (SELECT hashtags.id FROM hashtags
      LEFT OUTER JOIN hashtags_objects
        ON hashtags_objects.hashtag_id = hashtags.id
      WHERE hashtags_objects.hashtag_id IS NULL AND hashtags.id = ANY($1));
  """

  def delete_unreferenced(ids) do
    with {:ok, %{num_rows: deleted_count}} <- Repo.query(@delete_unreferenced_query, [ids]) do
      {:ok, deleted_count}
    end
  end
end
