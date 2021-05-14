# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.TagValidator do
  use Ecto.Schema

  alias Pleroma.EctoType.ActivityPub.ObjectValidators

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    # Common
    field(:type, :string)
    field(:name, :string)

    # Mention, Hashtag
    field(:href, ObjectValidators.Uri)

    # Emoji
    embeds_one :icon, IconObjectValidator, primary_key: false do
      field(:type, :string)
      field(:url, ObjectValidators.Uri)
    end

    field(:updated, ObjectValidators.DateTime)
    field(:id, ObjectValidators.Uri)
  end

  def cast_and_validate(data) do
    data
    |> cast_data()
  end

  def cast_data(data) do
    %__MODULE__{}
    |> changeset(data)
  end

  def changeset(struct, %{"type" => "Mention"} = data) do
    struct
    |> cast(data, [:type, :name, :href])
    |> validate_required([:type, :href])
  end

  def changeset(struct, %{"type" => "Hashtag", "name" => name} = data) do
    name =
      cond do
        "#" <> name -> name
        name -> name
      end
      |> String.downcase()

    data = Map.put(data, "name", name)

    struct
    |> cast(data, [:type, :name, :href])
    |> validate_required([:type, :name])
  end

  def changeset(struct, %{"type" => "Emoji"} = data) do
    data = Map.put(data, "name", String.trim(data["name"], ":"))

    struct
    |> cast(data, [:type, :name, :updated, :id])
    |> cast_embed(:icon, with: &icon_changeset/2)
    |> validate_required([:type, :name, :icon])
  end

  def icon_changeset(struct, data) do
    struct
    |> cast(data, [:type, :url])
    |> validate_inclusion(:type, ~w[Image])
    |> validate_required([:type, :url])
  end
end
