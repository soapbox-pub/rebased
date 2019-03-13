# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Object do
  use Ecto.Schema

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.ObjectTombstone
  alias Pleroma.Repo
  alias Pleroma.User

  import Ecto.Query
  import Ecto.Changeset

  schema "objects" do
    field(:data, :map)

    timestamps()
  end

  def create(data) do
    Object.change(%Object{}, %{data: data})
    |> Repo.insert()
  end

  def change(struct, params \\ %{}) do
    struct
    |> cast(params, [:data])
    |> validate_required([:data])
    |> unique_constraint(:ap_id, name: :objects_unique_apid_index)
  end

  def get_by_ap_id(nil), do: nil

  def get_by_ap_id(ap_id) do
    Repo.one(from(object in Object, where: fragment("(?)->>'id' = ?", object.data, ^ap_id)))
  end

  def normalize(%{"id" => ap_id}), do: normalize(ap_id)
  def normalize(ap_id) when is_binary(ap_id), do: get_cached_by_ap_id(ap_id)
  def normalize(_), do: nil

  # Owned objects can only be mutated by their owner
  def authorize_mutation(%Object{data: %{"actor" => actor}}, %User{ap_id: ap_id}),
    do: actor == ap_id

  # Legacy objects can be mutated by anybody
  def authorize_mutation(%Object{}, %User{}), do: true

  def get_cached_by_ap_id(ap_id) do
    key = "object:#{ap_id}"

    Cachex.fetch!(:object_cache, key, fn _ ->
      object = get_by_ap_id(ap_id)

      if object do
        {:commit, object}
      else
        {:ignore, object}
      end
    end)
  end

  def context_mapping(context) do
    Object.change(%Object{}, %{data: %{"id" => context}})
  end

  def make_tombstone(%Object{data: %{"id" => id, "type" => type}}, deleted \\ DateTime.utc_now()) do
    %ObjectTombstone{
      id: id,
      formerType: type,
      deleted: deleted
    }
    |> Map.from_struct()
  end

  def swap_object_with_tombstone(object) do
    tombstone = make_tombstone(object)

    object
    |> Object.change(%{data: tombstone})
    |> Repo.update()
  end

  def delete(%Object{data: %{"id" => id}} = object) do
    with {:ok, _obj} = swap_object_with_tombstone(object),
         deleted_activity = Activity.delete_by_ap_id(id),
         {:ok, true} <- Cachex.del(:object_cache, "object:#{id}") do
      {:ok, object, deleted_activity}
    end
  end

  def set_cache(%Object{data: %{"id" => ap_id}} = object) do
    Cachex.put(:object_cache, "object:#{ap_id}", object)
    {:ok, object}
  end

  def update_and_set_cache(changeset) do
    with {:ok, object} <- Repo.update(changeset) do
      set_cache(object)
    else
      e -> e
    end
  end
end
