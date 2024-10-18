# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.BiteValidator do
  use Ecto.Schema

  alias Pleroma.EctoType.ActivityPub.ObjectValidators

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

    field(:target, ObjectValidators.ObjectID)
  end

  def cast_data(data) do
    %__MODULE__{}
    |> cast(data |> fix_object(), __schema__(:fields))
  end

  defp fix_object(data) do
    Map.put(data, "object", data["target"])
  end

  defp validate_data(cng) do
    cng
    |> validate_required([:id, :type, :actor, :to, :target])
    |> validate_inclusion(:type, ["Bite"])
    |> validate_actor_presence()
    |> validate_object_or_user_presence(field_name: :target)
  end

  def cast_and_validate(data) do
    data
    |> cast_data
    |> validate_data
  end
end
