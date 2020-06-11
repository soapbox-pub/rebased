# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.QuestionOptionsValidator do
  use Ecto.Schema

  alias Pleroma.Web.ActivityPub.ObjectValidators.QuestionOptionsRepliesValidator

  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field(:name, :string)
    embeds_one(:replies, QuestionOptionsRepliesValidator)
    field(:type, :string)
  end

  def changeset(struct, data) do
    struct
    |> cast(data, [:name, :type])
    |> cast_embed(:replies)
    |> validate_inclusion(:type, ["Note"])
    |> validate_required([:name, :type])
  end
end

defmodule Pleroma.Web.ActivityPub.ObjectValidators.QuestionOptionsRepliesValidator do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field(:totalItems, :integer)
    field(:type, :string)
  end

  def changeset(struct, data) do
    struct
    |> cast(data, __schema__(:fields))
    |> validate_inclusion(:type, ["Collection"])
    |> validate_required([:type])
  end
end
