# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.BlockValidator do
  use Ecto.Schema

  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.User

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  @primary_key false

  embedded_schema do
    field(:id, ObjectValidators.ObjectID, primary_key: true)
    field(:type, :string)
    field(:actor, ObjectValidators.ObjectID)
    field(:to, ObjectValidators.Recipients, default: [])
    field(:cc, ObjectValidators.Recipients, default: [])
    field(:object, ObjectValidators.ObjectID)
  end

  def cast_data(data) do
    %__MODULE__{}
    |> cast(data, __schema__(:fields))
  end

  def validate_data(cng) do
    cng
    |> validate_required([:id, :type, :actor, :to, :cc, :object])
    |> validate_inclusion(:type, ["Block"])
    |> validate_actor_presence()
    |> validate_actor_presence(field_name: :object)
    |> validate_block_acceptance()
  end

  def cast_and_validate(data) do
    data
    |> cast_data
    |> validate_data
  end

  def validate_block_acceptance(cng) do
    actor = get_field(cng, :actor) |> User.get_cached_by_ap_id()

    if actor.local || Pleroma.Config.get([:activitypub, :unfollow_blocked], true) do
      cng
    else
      cng
      |> add_error(:actor, "Not accepting remote blocks")
    end
  end
end
