# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.AcceptRejectValidator do
  use Ecto.Schema

  alias Pleroma.Activity

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

  defp validate_data(cng) do
    cng
    |> validate_required([:id, :type, :actor, :to, :cc, :object])
    |> validate_inclusion(:type, ["Accept", "Reject"])
    |> validate_actor_presence()
    |> validate_object_presence(allowed_types: ["Follow"])
    |> validate_accept_reject_rights()
  end

  def cast_and_validate(data) do
    data
    |> cast_data
    |> validate_data
  end

  def validate_accept_reject_rights(cng) do
    with object_id when is_binary(object_id) <- get_field(cng, :object),
         %Activity{data: %{"object" => followed_actor}} <- Activity.get_by_ap_id(object_id),
         true <- followed_actor == get_field(cng, :actor) do
      cng
    else
      _e ->
        cng
        |> add_error(:actor, "can't accept or reject the given activity")
    end
  end
end
