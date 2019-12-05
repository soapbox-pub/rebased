# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.NoteValidator do
  use Ecto.Schema

  alias Pleroma.Web.ActivityPub.ObjectValidators.Types

  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field(:id, :string, primary_key: true)
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
    field(:inRepyTo, :string)

    field(:likes, {:array, :string}, default: [])
    field(:announcements, {:array, :string}, default: [])

    # see if needed
    field(:conversation, :string)
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
