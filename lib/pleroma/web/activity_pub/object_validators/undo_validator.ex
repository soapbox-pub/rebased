# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.UndoValidator do
  use Ecto.Schema

  alias Pleroma.Activity
  alias Pleroma.User

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
  end

  defp validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["Undo"])
    |> validate_required([:id, :type, :object, :actor, :to, :cc])
    |> validate_undo_actor(:actor)
    |> validate_object_presence()
    |> validate_undo_rights()
  end

  def validate_undo_rights(cng) do
    actor = get_field(cng, :actor)
    object = get_field(cng, :object)

    with %Activity{data: %{"actor" => object_actor}} <- Activity.get_by_ap_id(object),
         true <- object_actor != actor do
      cng
      |> add_error(:actor, "not the same as object actor")
    else
      _ -> cng
    end
  end

  defp validate_undo_actor(cng, field_name) do
    validate_change(cng, field_name, fn field_name, actor ->
      case User.get_cached_by_ap_id(actor) do
        %User{} -> []
        _ -> [{field_name, "can't find user"}]
      end
    end)
  end
end
