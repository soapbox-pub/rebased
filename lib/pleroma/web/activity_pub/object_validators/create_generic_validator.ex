# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

# Code based on CreateChatMessageValidator
# NOTES
# - doesn't embed, will only get the object id
defmodule Pleroma.Web.ActivityPub.ObjectValidators.CreateGenericValidator do
  use Ecto.Schema

  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonFixes
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field(:id, ObjectValidators.ObjectID, primary_key: true)
    field(:actor, ObjectValidators.ObjectID)
    field(:type, :string)
    field(:to, ObjectValidators.Recipients, default: [])
    field(:cc, ObjectValidators.Recipients, default: [])
    field(:object, ObjectValidators.ObjectID)
    field(:expires_at, ObjectValidators.DateTime)

    # Should be moved to object, done for CommonAPI.Utils.make_context
    field(:context, :string)
  end

  def cast_data(data, meta \\ []) do
    data = fix(data, meta)

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
    |> cast_data(meta)
    |> validate_data(meta)
  end

  def changeset(struct, data) do
    struct
    |> cast(data, __schema__(:fields))
  end

  defp fix_context(data, meta) do
    if object = meta[:object_data] do
      Map.put_new(data, "context", object["context"])
    else
      data
    end
  end

  defp fix(data, meta) do
    data
    |> fix_context(meta)
    |> CommonFixes.fix_actor()
    |> CommonFixes.fix_activity_defaults(meta)
  end

  defp validate_data(cng, meta) do
    cng
    |> validate_required([:actor, :type, :object])
    |> validate_inclusion(:type, ["Create"])
    |> CommonValidations.validate_actor_presence()
    |> CommonValidations.validate_any_presence([:to, :cc])
    |> validate_actors_match(meta)
    |> validate_context_match(meta)
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
    attributed_to = meta[:object_data]["attributedTo"] || meta[:object_data]["actor"]

    cng
    |> validate_change(:actor, fn :actor, actor ->
      if actor == attributed_to do
        []
      else
        [{:actor, "Actor doesn't match with object attributedTo"}]
      end
    end)
  end

  def validate_context_match(cng, %{object_data: %{"context" => object_context}}) do
    cng
    |> validate_change(:context, fn :context, context ->
      if context == object_context do
        []
      else
        [{:context, "context field not matching between Create and object (#{object_context})"}]
      end
    end)
  end

  def validate_context_match(cng, _), do: cng
end
