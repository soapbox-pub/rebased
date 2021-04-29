# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.UndoValidator do
  use Ecto.Schema

  alias Pleroma.Activity
  alias Pleroma.EctoType.ActivityPub.ObjectValidators

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  @primary_key false

  embedded_schema do
    field(:id, ObjectValidators.ObjectID, primary_key: true)
    field(:type, :string)
    field(:object, ObjectValidators.ObjectID)
    field(:actor, ObjectValidators.ObjectID)
    field(:to, ObjectValidators.Recipients, default: [])
    field(:cc, ObjectValidators.Recipients, default: [])
  end

  def cast_and_validate(data) do
    data
    |> cast_data()
    |> validate_data()
  end

  def cast_data(data) do
    %__MODULE__{}
    |> changeset(data)
  end

  def changeset(struct, data) do
    struct
    |> cast(data, __schema__(:fields))
  end

  defp validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["Undo"])
    |> validate_required([:id, :type, :object, :actor, :to, :cc])
    |> validate_actor_presence()
    |> validate_object_presence()
    |> validate_undo_rights()
  end

  def validate_undo_rights(cng) do
    actor = get_field(cng, :actor)
    object = get_field(cng, :object)

    with %Activity{data: %{"actor" => object_actor}} <- Activity.get_by_ap_id(object),
         true <- object_actor != actor do
      cng
      |> add_error(:actor, "not the same as object actor")
    else
      _ -> cng
    end
  end
end
