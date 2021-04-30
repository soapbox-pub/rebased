# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.QuestionValidator do
  use Ecto.Schema

  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Web.ActivityPub.ObjectValidators.AttachmentValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonFixes
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations
  alias Pleroma.Web.ActivityPub.ObjectValidators.QuestionOptionsValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.TagValidator
  alias Pleroma.Web.ActivityPub.Transmogrifier

  import Ecto.Changeset

  @primary_key false
  @derive Jason.Encoder

  # Extends from NoteValidator
  embedded_schema do
    field(:id, ObjectValidators.ObjectID, primary_key: true)
    field(:to, ObjectValidators.Recipients, default: [])
    field(:cc, ObjectValidators.Recipients, default: [])
    field(:bto, ObjectValidators.Recipients, default: [])
    field(:bcc, ObjectValidators.Recipients, default: [])
    embeds_many(:tag, TagValidator)
    field(:type, :string)
    field(:content, :string)
    field(:context, :string)

    # TODO: Remove actor on objects
    field(:actor, ObjectValidators.ObjectID)

    field(:attributedTo, ObjectValidators.ObjectID)
    field(:summary, :string)
    field(:published, ObjectValidators.DateTime)
    field(:emoji, ObjectValidators.Emoji, default: %{})
    field(:sensitive, :boolean, default: false)
    embeds_many(:attachment, AttachmentValidator)
    field(:replies_count, :integer, default: 0)
    field(:like_count, :integer, default: 0)
    field(:announcement_count, :integer, default: 0)
    field(:inReplyTo, ObjectValidators.ObjectID)
    field(:url, ObjectValidators.Uri)
    # short identifier for PleromaFE to group statuses by context
    field(:context_id, :integer)

    field(:likes, {:array, ObjectValidators.ObjectID}, default: [])
    field(:announcements, {:array, ObjectValidators.ObjectID}, default: [])

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
    |> CommonFixes.fix_defaults()
    |> CommonFixes.fix_attribution()
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
