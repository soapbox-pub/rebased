# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.LeaveValidator do
  use Ecto.Schema

  alias Pleroma.Web.ActivityPub.Utils

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

  def cast_data(data) do
    %__MODULE__{}
    |> cast(data, __schema__(:fields))
  end

  defp validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["Leave"])
    |> validate_required([:id, :type, :actor, :to, :cc, :object])
    |> validate_actor_presence()
    |> validate_object_presence(allowed_types: ["Event"])
    |> validate_existing_join()
  end

  def cast_and_validate(data) do
    data
    |> cast_data()
    |> validate_data()
  end

  defp validate_existing_join(%{changes: %{actor: actor, object: object}} = cng) do
    if !Utils.get_existing_join(actor, object) do
      cng
      |> add_error(:actor, "not joined this event")
      |> add_error(:object, "not joined by this actor")
    else
      cng
    end
  end

  defp validate_existing_join(cng), do: cng
end
