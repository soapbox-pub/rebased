# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.UpdateValidator do
  use Ecto.Schema

  alias Pleroma.EctoType.ActivityPub.ObjectValidators

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  @primary_key false

  embedded_schema do
    field(:id, ObjectValidators.ObjectID, primary_key: true)
    field(:type, :string)
    field(:actor, ObjectValidators.ObjectID)
    field(:to, ObjectValidators.Recipients, default: [])
    field(:cc, ObjectValidators.Recipients, default: [])
    # In this case, we save the full object in this activity instead of just a
    # reference, so we can always see what was actually changed by this.
    field(:object, :map)
  end

  def cast_data(data) do
    %__MODULE__{}
    |> cast(data, __schema__(:fields))
  end

  def validate_data(cng) do
    cng
    |> validate_required([:id, :type, :actor, :to, :cc, :object])
    |> validate_inclusion(:type, ["Update"])
    |> validate_actor_presence()
  end

  def cast_and_validate(data) do
    data
    |> cast_data
    |> validate_data
  end
end
