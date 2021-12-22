# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.FollowValidator do
  use Ecto.Schema

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

    field(:state, :string, default: "pending")
  end

  def cast_data(data) do
    %__MODULE__{}
    |> cast(data, __schema__(:fields))
  end

  defp validate_data(cng) do
    cng
    |> validate_required([:id, :type, :actor, :to, :cc, :object])
    |> validate_inclusion(:type, ["Follow"])
    |> validate_inclusion(:state, ~w{pending reject accept})
    |> validate_actor_presence()
    |> validate_actor_presence(field_name: :object)
  end

  def cast_and_validate(data) do
    data
    |> cast_data
    |> validate_data
  end
end
