# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.EmojiReactValidator do
  use Ecto.Schema

  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonFixes

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  @primary_key false

  embedded_schema do
    quote do
      unquote do
        import Elixir.Pleroma.Web.ActivityPub.ObjectValidators.CommonFields
        message_fields()
        activity_fields()
      end
    end

    field(:context, :string)
    field(:content, :string)
  end

  def cast_and_validate(data) do
    data
    |> cast_data()
    |> validate_data()
  end

  def cast_data(data) do
    data =
      data
      |> fix()

    %__MODULE__{}
    |> changeset(data)
  end

  def changeset(struct, data) do
    struct
    |> cast(data, __schema__(:fields))
  end

  defp fix(data) do
    data =
      data
      |> CommonFixes.fix_actor()
      |> CommonFixes.fix_activity_addressing()

    with %Object{} = object <- Object.normalize(data["object"]) do
      data
      |> CommonFixes.fix_activity_context(object)
      |> CommonFixes.fix_object_action_recipients(object)
    else
      _ -> data
    end
  end

  defp validate_emoji(cng) do
    content = get_field(cng, :content)

    if Pleroma.Emoji.is_unicode_emoji?(content) do
      cng
    else
      cng
      |> add_error(:content, "must be a single character emoji")
    end
  end

  defp validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["EmojiReact"])
    |> validate_required([:id, :type, :object, :actor, :context, :to, :cc, :content])
    |> validate_actor_presence()
    |> validate_object_presence()
    |> validate_emoji()
  end
end
