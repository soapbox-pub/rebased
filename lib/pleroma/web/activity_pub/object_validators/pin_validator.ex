# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.PinValidator do
  use Ecto.Schema

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  alias Pleroma.EctoType.ActivityPub.ObjectValidators

  @primary_key false

  embedded_schema do
    field(:id, ObjectValidators.ObjectID, primary_key: true)
    field(:target)
    field(:object, ObjectValidators.ObjectID)
    field(:actor, ObjectValidators.ObjectID)
    field(:type)
    field(:to, ObjectValidators.Recipients, default: [])
    field(:cc, ObjectValidators.Recipients, default: [])
  end

  def cast_and_validate(data) do
    data
    |> cast_data()
    |> validate_data()
  end

  defp cast_data(data) do
    cast(%__MODULE__{}, data, __schema__(:fields))
  end

  defp validate_data(changeset) do
    changeset
    |> validate_required([:id, :target, :object, :actor, :type, :to, :cc])
    |> validate_inclusion(:type, ~w(Add Remove))
    |> validate_actor_presence()
    |> validate_object_presence()
  end
end
