# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.UrlObjectValidator do
  use Ecto.Schema

  alias Pleroma.EctoType.ActivityPub.ObjectValidators

  import Ecto.Changeset
  @primary_key false

  embedded_schema do
    field(:type, :string)
    field(:href, ObjectValidators.Uri)
    field(:mediaType, :string, default: "application/octet-stream")
  end

  def changeset(struct, data) do
    struct
    |> cast(data, __schema__(:fields))
    |> validate_required([:type, :href, :mediaType])
  end
end
