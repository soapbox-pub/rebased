# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.EmojiReactValidator do
  use Ecto.Schema

  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.ObjectValidators.Types

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  @primary_key false

  embedded_schema do
    field(:id, Types.ObjectID, primary_key: true)
    field(:type, :string)
    field(:object, Types.ObjectID)
    field(:actor, Types.ObjectID)
    field(:context, :string)
    field(:content, :string)
    field(:to, {:array, :string}, default: [])
    field(:cc, {:array, :string}, default: [])
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

  def changeset(struct, data) do
    struct
    |> cast(data, __schema__(:fields))
    |> fix_after_cast()
  end

  def fix_after_cast(cng) do
    cng
    |> fix_context()
  end

  def fix_context(cng) do
    object = get_field(cng, :object)

    with nil <- get_field(cng, :context),
         %Object{data: %{"context" => context}} <- Object.get_cached_by_ap_id(object) do
      cng
      |> put_change(:context, context)
    else
      _ ->
        cng
    end
  end

  def validate_emoji(cng) do
    content = get_field(cng, :content)

    if Pleroma.Emoji.is_unicode_emoji?(content) do
      cng
    else
      cng
      |> add_error(:content, "must be a single character emoji")
    end
  end

  def validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["EmojiReact"])
    |> validate_required([:id, :type, :object, :actor, :context, :to, :cc, :content])
    |> validate_actor_presence()
    |> validate_object_presence()
    |> validate_emoji()
  end
end
