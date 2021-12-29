# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Migrators.Support.ObjectId do
  @moduledoc """
  Functions for migrating Object IDs.
  """
  alias Pleroma.Chat.MessageReference
  alias Pleroma.DataMigrationFailedId
  alias Pleroma.Delivery
  alias Pleroma.HashtagObject
  alias Pleroma.Object
  alias Pleroma.Repo

  import Ecto.Changeset
  import Ecto.Query

  @doc "Change an object's ID including all references."
  def change_id(%Object{id: old_id} = object, new_id) do
    Repo.transaction(fn ->
      with {:ok, object} <- Repo.update(change(object, id: new_id)),
           {:ok, _} <- update_object_fk(MessageReference, old_id, new_id),
           {:ok, _} <- update_object_fk(Delivery, old_id, new_id),
           {:ok, _} <- update_object_fk(HashtagObject, old_id, new_id),
           {:ok, _} <- update_object_fk(DataMigrationFailedId, old_id, new_id, :record_id) do
        {:ok, object}
      end
    end)
  end

  defp update_object_fk(schema, old_id, new_id, field \\ :object_id) do
    binding = [{field, old_id}]

    schema
    |> where(^binding)
    |> Repo.update_all(set: [{field, new_id}])
  end

  @doc "Shift a FlakeId by N places."
  def shift_id(flake_id, n) when is_integer(n) do
    flake_id
    |> FlakeId.from_string()
    |> FlakeId.to_integer()
    |> Kernel.+(n)
    |> FlakeId.from_integer()
    |> FlakeId.to_string()
  end
end
