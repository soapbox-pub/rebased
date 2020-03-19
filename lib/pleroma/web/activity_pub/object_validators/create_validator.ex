# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.CreateNoteValidator do
  use Ecto.Schema

  alias Pleroma.Web.ActivityPub.ObjectValidators.NoteValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.Types

  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field(:id, :string, primary_key: true)
    field(:actor, Types.ObjectID)
    field(:type, :string)
    field(:to, {:array, :string})
    field(:cc, {:array, :string})
    field(:bto, {:array, :string}, default: [])
    field(:bcc, {:array, :string}, default: [])

    embeds_one(:object, NoteValidator)
  end

  def cast_data(data) do
    %__MODULE__{}
    |> cast(data, __schema__(:fields))
  end
end
