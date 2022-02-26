# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

# NOTES
# - Can probably be a generic create validator
# - doesn't embed, will only get the object id
defmodule Pleroma.Web.ActivityPub.ObjectValidators.CreateChatMessageValidator do
  use Ecto.Schema
  alias Pleroma.EctoType.ActivityPub.ObjectValidators

  alias Pleroma.Object

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  @primary_key false

  embedded_schema do
    quote do
      unquote do
        import Elixir.Pleroma.Web.ActivityPub.ObjectValidators.CommonFields
        activity_fields()
      end
    end

    field(:id, ObjectValidators.ObjectID, primary_key: true)
    field(:type, :string)
    field(:to, ObjectValidators.Recipients, default: [])
  end

  def cast_and_apply(data) do
    data
    |> cast_data
    |> apply_action(:insert)
  end

  def cast_data(data) do
    cast(%__MODULE__{}, data, __schema__(:fields))
  end

  def cast_and_validate(data, meta \\ []) do
    cast_data(data)
    |> validate_data(meta)
  end

  defp validate_data(cng, meta) do
    cng
    |> validate_required([:id, :actor, :to, :type, :object])
    |> validate_inclusion(:type, ["Create"])
    |> validate_actor_presence()
    |> validate_recipients_match(meta)
    |> validate_actors_match(meta)
    |> validate_object_nonexistence()
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

  def validate_recipients_match(cng, meta) do
    object_recipients = meta[:object_data]["to"] || []

    cng
    |> validate_change(:to, fn :to, recipients ->
      activity_set = MapSet.new(recipients)
      object_set = MapSet.new(object_recipients)

      if MapSet.equal?(activity_set, object_set) do
        []
      else
        [{:to, "Recipients don't match with object recipients"}]
      end
    end)
  end
end
