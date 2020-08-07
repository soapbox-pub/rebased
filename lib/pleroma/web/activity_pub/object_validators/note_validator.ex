# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.NoteValidator do
  use Ecto.Schema

  alias Pleroma.EctoType.ActivityPub.ObjectValidators

  import Ecto.Changeset

  @primary_key false

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
    field(:actor, ObjectValidators.ObjectID)
    field(:attributedTo, ObjectValidators.ObjectID)
    field(:summary, :string)
    field(:published, ObjectValidators.DateTime)
    # TODO: Write type
    field(:emoji, :map, default: %{})
    field(:sensitive, :boolean, default: false)
    # TODO: Write type
    field(:attachment, {:array, :map}, default: [])
    field(:replies_count, :integer, default: 0)
    field(:like_count, :integer, default: 0)
    field(:announcement_count, :integer, default: 0)
    field(:inReplyTo, :string)
    field(:uri, ObjectValidators.Uri)

    field(:likes, {:array, :string}, default: [])
    field(:announcements, {:array, :string}, default: [])

    # see if needed
    field(:context_id, :string)
  end

  def cast_and_validate(data) do
    data
    |> cast_data()
    |> validate_data()
  end

  def cast_data(data) do
    %__MODULE__{}
    |> cast(data, __schema__(:fields))
  end

  def validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["Note"])
    |> validate_required([:id, :actor, :to, :cc, :type, :content, :context])
  end
end
