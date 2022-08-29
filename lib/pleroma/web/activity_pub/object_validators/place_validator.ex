# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.PlaceValidator do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:type, :string)
    field(:name, :string)
    field(:longitude, :float)
    field(:latitude, :float)
    field(:accuracy, :float)
    field(:altitude, :float)
    field(:radius, :float)
    field(:units, :string)

    embeds_one :address, Address do
      field(:type, :string)
      field(:postalCode, :string)
      field(:addressRegion, :string)
      field(:streetAddress, :string)
      field(:addressCountry, :string)
      field(:addressLocality, :string)
    end
  end

  def changeset(struct, data) do
    struct
    |> cast(data, [:type, :name, :longitude, :latitude, :accuracy, :altitude, :radius, :units])
    |> cast_embed(:address, with: &address_changeset/2)
    |> validate_inclusion(:type, ["Place"])
    |> validate_inclusion(:radius, ~w[cm feet inches km m miles])
    |> validate_number(:accuracy, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:radius, greater_than_or_equal_to: 0)
    |> validate_required([:type, :name])
  end

  def address_changeset(struct, data) do
    struct
    |> cast(data, [
      :type,
      :postalCode,
      :addressRegion,
      :streetAddress,
      :addressCountry,
      :addressLocality
    ])
    |> validate_inclusion(:type, ["PostalAddress"])
  end
end
