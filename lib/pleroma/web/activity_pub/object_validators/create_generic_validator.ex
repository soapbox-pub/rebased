# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

# Code based on CreateChatMessageValidator
# NOTES
# - doesn't embed, will only get the object id
defmodule Pleroma.Web.ActivityPub.ObjectValidators.CreateGenericValidator do
  use Ecto.Schema

  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Object

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  @primary_key false

  embedded_schema do
    field(:id, ObjectValidators.ObjectID, primary_key: true)
    field(:actor, ObjectValidators.ObjectID)
    field(:type, :string)
    field(:to, ObjectValidators.Recipients, default: [])
    field(:cc, ObjectValidators.Recipients, default: [])
    field(:object, ObjectValidators.ObjectID)
    field(:expires_at, ObjectValidators.DateTime)
  end

  def cast_data(data) do
    %__MODULE__{}
    |> changeset(data)
  end

  def cast_and_apply(data) do
    data
    |> cast_data
    |> apply_action(:insert)
  end

  def cast_and_validate(data, meta \\ []) do
    data
    |> cast_data
    |> validate_data(meta)
  end

  def changeset(struct, data) do
    struct
    |> cast(data, __schema__(:fields))
  end

  def validate_data(cng, meta \\ []) do
    cng
    |> validate_required([:actor, :type, :object])
    |> validate_inclusion(:type, ["Create"])
    |> validate_actor_is_active()
    |> validate_any_presence([:to, :cc])
    |> validate_actors_match(meta)
    |> validate_object_nonexistence()
    |> validate_object_containment()
  end

  def validate_object_containment(cng) do
    actor = get_field(cng, :actor)

    cng
    |> validate_change(:object, fn :object, object_id ->
      %URI{host: object_id_host} = URI.parse(object_id)
      %URI{host: actor_host} = URI.parse(actor)

      if object_id_host == actor_host do
        []
      else
        [{:object, "The host of the object id doesn't match with the host of the actor"}]
      end
    end)
  end

  def validate_object_nonexistence(cng) do
    cng
    |> validate_change(:object, fn :object, object_id ->
      if Object.get_cached_by_ap_id(object_id) do
        [{:object, "The object to create already exists"}]
      else
        []
      end
    end)
  end

  def validate_actors_match(cng, meta) do
    object_actor = meta[:object_data]["actor"]

    cng
    |> validate_change(:actor, fn :actor, actor ->
      if actor == object_actor do
        []
      else
        [{:actor, "Actor doesn't match with object actor"}]
      end
    end)
  end
end
