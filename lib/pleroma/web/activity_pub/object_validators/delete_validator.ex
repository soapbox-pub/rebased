# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.DeleteValidator do
  use Ecto.Schema

  alias Pleroma.Activity
  alias Pleroma.Web.ActivityPub.ObjectValidators.Types

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  @primary_key false

  embedded_schema do
    field(:id, Types.ObjectID, primary_key: true)
    field(:type, :string)
    field(:actor, Types.ObjectID)
    field(:to, Types.Recipients, default: [])
    field(:cc, Types.Recipients, default: [])
    field(:deleted_activity_id)
    field(:object, Types.ObjectID)
  end

  def cast_data(data) do
    %__MODULE__{}
    |> cast(data, __schema__(:fields))
  end

  def add_deleted_activity_id(cng) do
    object =
      cng
      |> get_field(:object)

    with %Activity{id: id} <- Activity.get_create_by_object_ap_id(object) do
      cng
      |> put_change(:deleted_activity_id, id)
    else
      _ -> cng
    end
  end

  def validate_data(cng) do
    cng
    |> validate_required([:id, :type, :actor, :to, :cc, :object])
    |> validate_inclusion(:type, ["Delete"])
    |> validate_same_domain()
    |> validate_object_or_user_presence()
    |> add_deleted_activity_id()
  end

  def validate_same_domain(cng) do
    actor_domain =
      cng
      |> get_field(:actor)
      |> URI.parse()
      |> (& &1.host).()

    object_domain =
      cng
      |> get_field(:object)
      |> URI.parse()
      |> (& &1.host).()

    if object_domain != actor_domain do
      cng
      |> add_error(:actor, "is not allowed to delete object")
    else
      cng
    end
  end

  def cast_and_validate(data) do
    data
    |> cast_data
    |> validate_data
  end
end
