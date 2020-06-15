# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.QuestionValidator do
  use Ecto.Schema

  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations
  alias Pleroma.Web.ActivityPub.ObjectValidators.QuestionOptionsValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.Types

  import Ecto.Changeset

  @primary_key false
  @derive Jason.Encoder

  # Extends from NoteValidator
  embedded_schema do
    field(:id, Types.ObjectID, primary_key: true)
    field(:to, {:array, :string}, default: [])
    field(:cc, {:array, :string}, default: [])
    field(:bto, {:array, :string}, default: [])
    field(:bcc, {:array, :string}, default: [])
    # TODO: Write type
    field(:tag, {:array, :map}, default: [])
    field(:type, :string)
    field(:content, :string)
    field(:context, :string)
    field(:actor, Types.ObjectID)
    field(:attributedTo, Types.ObjectID)
    field(:summary, :string)
    field(:published, Types.DateTime)
    # TODO: Write type
    field(:emoji, :map, default: %{})
    field(:sensitive, :boolean, default: false)
    # TODO: Write type
    field(:attachment, {:array, :map}, default: [])
    field(:replies_count, :integer, default: 0)
    field(:like_count, :integer, default: 0)
    field(:announcement_count, :integer, default: 0)
    field(:inReplyTo, :string)
    field(:uri, Types.Uri)

    field(:likes, {:array, :string}, default: [])
    field(:announcements, {:array, :string}, default: [])

    # see if needed
    field(:conversation, :string)
    field(:context_id, :string)

    field(:closed, Types.DateTime)
    field(:voters, {:array, Types.ObjectID}, default: [])
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

  def fix(data) do
    cond do
      is_binary(data["closed"]) -> data
      is_binary(data["endTime"]) -> Map.put(data, "closed", data["endTime"])
      true -> Map.drop(data, ["closed"])
    end
  end

  def changeset(struct, data) do
    data = fix(data)

    struct
    |> cast(data, __schema__(:fields) -- [:anyOf, :oneOf])
    |> cast_embed(:anyOf)
    |> cast_embed(:oneOf)
  end

  def validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["Question"])
    |> validate_required([:id, :actor, :type, :content, :context])
    |> CommonValidations.validate_any_presence([:cc, :to])
    |> CommonValidations.validate_actor_presence()
    |> CommonValidations.validate_any_presence([:oneOf, :anyOf])
  end
end
