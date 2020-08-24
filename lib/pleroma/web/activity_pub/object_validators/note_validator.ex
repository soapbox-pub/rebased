# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.NoteValidator do
  use Ecto.Schema

  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Web.ActivityPub.Transmogrifier

  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field(:id, ObjectValidators.ObjectID, primary_key: true)
    field(:to, ObjectValidators.Recipients, default: [])
    field(:cc, ObjectValidators.Recipients, default: [])
    field(:bto, ObjectValidators.Recipients, default: [])
    field(:bcc, ObjectValidators.Recipients, default: [])
    # TODO: Write type
    field(:tag, {:array, :map}, default: [])
    field(:type, :string)

    field(:name, :string)
    field(:summary, :string)
    field(:content, :string)

    field(:context, :string)
    # short identifier for PleromaFE to group statuses by context
    field(:context_id, :integer)

    field(:actor, ObjectValidators.ObjectID)
    field(:attributedTo, ObjectValidators.ObjectID)
    field(:published, ObjectValidators.DateTime)
    field(:emoji, ObjectValidators.Emoji, default: %{})
    field(:sensitive, :boolean, default: false)
    # TODO: Write type
    field(:attachment, {:array, :map}, default: [])
    field(:replies_count, :integer, default: 0)
    field(:like_count, :integer, default: 0)
    field(:announcement_count, :integer, default: 0)
    field(:inReplyTo, ObjectValidators.ObjectID)
    field(:url, ObjectValidators.Uri)

    field(:likes, {:array, :string}, default: [])
    field(:announcements, {:array, :string}, default: [])
  end

  def cast_and_validate(data) do
    data
    |> cast_data()
    |> validate_data()
  end

  defp fix(data) do
    data
    |> Transmogrifier.fix_emoji()
  end

  def cast_data(data) do
    data = fix(data)

    %__MODULE__{}
    |> cast(data, __schema__(:fields))
  end

  def validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["Note"])
    |> validate_required([:id, :actor, :to, :cc, :type, :content, :context])
  end
end
