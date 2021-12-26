# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.QuestionValidator do
  use Ecto.Schema

  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonFixes
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations
  alias Pleroma.Web.ActivityPub.ObjectValidators.QuestionOptionsValidator
  alias Pleroma.Web.ActivityPub.Transmogrifier

  import Ecto.Changeset

  @primary_key false
  @derive Jason.Encoder

  # Extends from NoteValidator
  embedded_schema do
    quote do
      unquote do
        import Elixir.Pleroma.Web.ActivityPub.ObjectValidators.CommonFields
        message_fields()
        object_fields()
        status_object_fields()
      end
    end

    field(:closed, ObjectValidators.DateTime)
    field(:voters, {:array, ObjectValidators.ObjectID}, default: [])
    embeds_many(:anyOf, QuestionOptionsValidator)
    embeds_many(:oneOf, QuestionOptionsValidator)
  end

  def cast_and_apply(data) do
    data
    |> cast_data
    |> apply_action(:insert)
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

  defp fix_closed(data) do
    cond do
      is_binary(data["closed"]) -> data
      is_binary(data["endTime"]) -> Map.put(data, "closed", data["endTime"])
      true -> Map.drop(data, ["closed"])
    end
  end

  defp fix(data) do
    data
    |> CommonFixes.fix_actor()
    |> CommonFixes.fix_object_defaults()
    |> Transmogrifier.fix_emoji()
    |> fix_closed()
  end

  def changeset(struct, data) do
    data = fix(data)

    struct
    |> cast(data, __schema__(:fields) -- [:anyOf, :oneOf, :attachment, :tag])
    |> cast_embed(:attachment)
    |> cast_embed(:anyOf)
    |> cast_embed(:oneOf)
    |> cast_embed(:tag)
  end

  defp validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["Question"])
    |> validate_required([:id, :actor, :attributedTo, :type, :context, :context_id])
    |> CommonValidations.validate_any_presence([:cc, :to])
    |> CommonValidations.validate_fields_match([:actor, :attributedTo])
    |> CommonValidations.validate_actor_presence()
    |> CommonValidations.validate_any_presence([:oneOf, :anyOf])
    |> CommonValidations.validate_host_match()
  end
end
