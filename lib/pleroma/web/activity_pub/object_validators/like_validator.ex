# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.LikeValidator do
  use Ecto.Schema

  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.Utils

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  @primary_key false

  embedded_schema do
    field(:id, ObjectValidators.ObjectID, primary_key: true)
    field(:type, :string)
    field(:object, ObjectValidators.ObjectID)
    field(:actor, ObjectValidators.ObjectID)
    field(:context, :string)
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
    |> fix_after_cast()
  end

  def fix_after_cast(cng) do
    cng
    |> fix_recipients()
    |> fix_context()
  end

  def fix_context(cng) do
    object = get_field(cng, :object)

    with nil <- get_field(cng, :context),
         %Object{data: %{"context" => context}} <- Object.get_cached_by_ap_id(object) do
      cng
      |> put_change(:context, context)
    else
      _ ->
        cng
    end
  end

  def fix_recipients(cng) do
    to = get_field(cng, :to)
    cc = get_field(cng, :cc)
    object = get_field(cng, :object)

    with {[], []} <- {to, cc},
         %Object{data: %{"actor" => actor}} <- Object.get_cached_by_ap_id(object),
         {:ok, actor} <- ObjectValidators.ObjectID.cast(actor) do
      cng
      |> put_change(:to, [actor])
    else
      _ ->
        cng
    end
  end

  defp validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["Like"])
    |> validate_required([:id, :type, :object, :actor, :context, :to, :cc])
    |> validate_actor_presence()
    |> validate_object_presence()
    |> validate_existing_like()
  end

  def validate_existing_like(%{changes: %{actor: actor, object: object}} = cng) do
    if Utils.get_existing_like(actor, %{data: %{"id" => object}}) do
      cng
      |> add_error(:actor, "already liked this object")
      |> add_error(:object, "already liked by this actor")
    else
      cng
    end
  end

  def validate_existing_like(cng), do: cng
end
