# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.AnnounceValidator do
  use Ecto.Schema

  alias Pleroma.Web.ActivityPub.ObjectValidators.Types
  alias Pleroma.Web.ActivityPub.Utils

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  @primary_key false

  embedded_schema do
    field(:id, Types.ObjectID, primary_key: true)
    field(:type, :string)
    field(:object, Types.ObjectID)
    field(:actor, Types.ObjectID)
    field(:context, :string)
    field(:to, Types.Recipients, default: [])
    field(:cc, Types.Recipients, default: [])
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
    |> fix_after_cast()
  end

  def fix_after_cast(cng) do
    cng
  end

  def validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["Announce"])
    |> validate_required([:id, :type, :object, :actor, :context, :to, :cc])
    |> validate_actor_presence()
    |> validate_object_presence()
    |> validate_existing_announce()
  end

  def validate_existing_announce(cng) do
    actor = get_field(cng, :actor)
    object = get_field(cng, :object)

    if actor && object && Utils.get_existing_announce(actor, %{data: %{"id" => object}}) do
      cng
      |> add_error(:actor, "already announced this object")
      |> add_error(:object, "already announced by this actor")
    else
      cng
    end
  end
end
