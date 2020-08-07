# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.QuestionValidator do
  use Ecto.Schema

  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Web.ActivityPub.ObjectValidators.AttachmentValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations
  alias Pleroma.Web.ActivityPub.ObjectValidators.QuestionOptionsValidator
  alias Pleroma.Web.ActivityPub.Utils

  import Ecto.Changeset

  @primary_key false
  @derive Jason.Encoder

  # Extends from NoteValidator
  embedded_schema do
    field(:id, ObjectValidators.ObjectID, primary_key: true)
    field(:to, {:array, :string}, default: [])
    field(:cc, {:array, :string}, default: [])
    field(:bto, {:array, :string}, default: [])
    field(:bcc, {:array, :string}, default: [])
    # TODO: Write type
    field(:tag, {:array, :map}, default: [])
    field(:type, :string)
    field(:content, :string)
    field(:context, :string)

    # TODO: Remove actor on objects
    field(:actor, ObjectValidators.ObjectID)

    field(:attributedTo, ObjectValidators.ObjectID)
    field(:summary, :string)
    field(:published, ObjectValidators.DateTime)
    # TODO: Write type
    field(:emoji, :map, default: %{})
    field(:sensitive, :boolean, default: false)
    embeds_many(:attachment, AttachmentValidator)
    field(:replies_count, :integer, default: 0)
    field(:like_count, :integer, default: 0)
    field(:announcement_count, :integer, default: 0)
    field(:inReplyTo, :string)
    field(:uri, ObjectValidators.Uri)
    # short identifier for PleromaFE to group statuses by context
    field(:context_id, :integer)

    field(:likes, {:array, :string}, default: [])
    field(:announcements, {:array, :string}, default: [])

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

  # based on Pleroma.Web.ActivityPub.Utils.lazy_put_objects_defaults
  defp fix_defaults(data) do
    %{data: %{"id" => context}, id: context_id} =
      Utils.create_context(data["context"] || data["conversation"])

    data
    |> Map.put_new_lazy("published", &Utils.make_date/0)
    |> Map.put_new("context", context)
    |> Map.put_new("context_id", context_id)
  end

  defp fix_attribution(data) do
    data
    |> Map.put_new("actor", data["attributedTo"])
  end

  defp fix(data) do
    data
    |> fix_attribution()
    |> fix_closed()
    |> fix_defaults()
  end

  def changeset(struct, data) do
    data = fix(data)

    struct
    |> cast(data, __schema__(:fields) -- [:anyOf, :oneOf, :attachment])
    |> cast_embed(:attachment)
    |> cast_embed(:anyOf)
    |> cast_embed(:oneOf)
  end

  def validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["Question"])
    |> validate_required([:id, :actor, :attributedTo, :type, :context])
    |> CommonValidations.validate_any_presence([:cc, :to])
    |> CommonValidations.validate_fields_match([:actor, :attributedTo])
    |> CommonValidations.validate_actor_presence()
    |> CommonValidations.validate_any_presence([:oneOf, :anyOf])
    |> CommonValidations.validate_host_match()
  end
end
