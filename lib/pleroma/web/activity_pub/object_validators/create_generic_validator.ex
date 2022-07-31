# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

# Code based on CreateChatMessageValidator
# NOTES
# - doesn't embed, will only get the object id
defmodule Pleroma.Web.ActivityPub.ObjectValidators.CreateGenericValidator do
  use Ecto.Schema

  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonFixes
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations
  alias Pleroma.Web.ActivityPub.Transmogrifier

  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    quote do
      unquote do
        import Elixir.Pleroma.Web.ActivityPub.ObjectValidators.CommonFields
        message_fields()
        activity_fields()
      end
    end

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

  # CommonFixes.fix_activity_addressing adapted for Create specific behavior
  defp fix_addressing(data, object) do
    %User{follower_address: follower_collection} = User.get_cached_by_ap_id(data["actor"])

    data
    |> CommonFixes.cast_and_filter_recipients("to", follower_collection, object["to"])
    |> CommonFixes.cast_and_filter_recipients("cc", follower_collection, object["cc"])
    |> CommonFixes.cast_and_filter_recipients("bto", follower_collection, object["bto"])
    |> CommonFixes.cast_and_filter_recipients("bcc", follower_collection, object["bcc"])
    |> Transmogrifier.fix_implicit_addressing(follower_collection)
  end

  def fix(data, meta) do
    object = meta[:object_data]

    data
    |> CommonFixes.fix_actor()
    |> Map.put_new("context", object["context"])
    |> fix_addressing(object)
  end

  defp validate_data(cng, meta) do
    object = meta[:object_data]

    cng
    |> validate_required([:actor, :type, :object, :to, :cc])
    |> validate_inclusion(:type, ["Create"])
    |> CommonValidations.validate_actor_presence()
    |> validate_actors_match(object)
    |> validate_context_match(object)
    |> validate_addressing_match(object)
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

  def validate_actors_match(cng, object) do
    attributed_to = object["attributedTo"] || object["actor"]

    cng
    |> validate_change(:actor, fn :actor, actor ->
      if actor == attributed_to do
        []
      else
        [{:actor, "Actor doesn't match with object attributedTo"}]
      end
    end)
  end

  def validate_context_match(cng, %{"context" => object_context}) do
    cng
    |> validate_change(:context, fn :context, context ->
      if context == object_context do
        []
      else
        [{:context, "context field not matching between Create and object (#{object_context})"}]
      end
    end)
  end

  def validate_addressing_match(cng, object) do
    [:to, :cc, :bcc, :bto]
    |> Enum.reduce(cng, fn field, cng ->
      object_data = object[to_string(field)]

      validate_change(cng, field, fn field, data ->
        if data == object_data do
          []
        else
          [{field, "field doesn't match with object (#{inspect(object_data)})"}]
        end
      end)
    end)
  end
end
