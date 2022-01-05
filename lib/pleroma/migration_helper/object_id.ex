# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.MigrationHelper.ObjectId do
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
      update_object_fk(MessageReference, old_id, new_id)
      update_object_fk(Delivery, old_id, new_id)
      update_object_fk(HashtagObject, old_id, new_id)
      update_object_fk(DataMigrationFailedId, old_id, new_id, :record_id)

      Repo.update!(change(object, id: new_id))
    end)
  end

  defp update_object_fk(schema, old_id, new_id, field \\ :object_id) do
    binding = [{field, old_id}]

    schema
    |> where(^binding)
    |> Repo.update_all(set: [{field, new_id}])
  end

  @doc "Generate a FlakeId from a datetime."
  @spec flake_from_time(NaiveDateTime.t()) :: flake_id :: String.t()
  def flake_from_time(%NaiveDateTime{} = dt) do
    dt
    |> build_worker()
    |> FlakeId.Worker.gen_flake()
    |> FlakeId.to_string()
  end

  # Build a one-off FlakeId worker.
  defp build_worker(%NaiveDateTime{} = dt) do
    %FlakeId.Worker{
      node: FlakeId.Worker.worker_id(),
      time: get_timestamp(dt, :millisecond)
    }
  end

  # Convert a NaiveDateTime into a Unix timestamp.
  @epoch ~N[1970-01-01 00:00:00]
  defp get_timestamp(%NaiveDateTime{} = dt, unit) do
    NaiveDateTime.diff(dt, @epoch, unit)
  end
end
