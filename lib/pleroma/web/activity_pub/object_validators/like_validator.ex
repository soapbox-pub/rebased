# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.LikeValidator do
  use Ecto.Schema

  alias Pleroma.Web.ActivityPub.ObjectValidators.Types
  alias Pleroma.Web.ActivityPub.Utils

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  @primary_key false

  embedded_schema do
    field(:id, :string, primary_key: true)
    field(:type, :string)
    field(:object, Types.ObjectID)
    field(:actor, Types.ObjectID)
    field(:context, :string)
    field(:to, {:array, :string})
    field(:cc, {:array, :string})
  end

  def cast_and_validate(data) do
    data
    |> cast_data()
    |> validate_data()
  end

  def cast_data(data) do
    %__MODULE__{}
    |> cast(data, [:id, :type, :object, :actor, :context, :to, :cc])
  end

  def validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["Like"])
    |> validate_required([:id, :type, :object, :actor, :context, :to, :cc])
    |> validate_actor_presence()
    |> validate_object_presence()
    |> validate_existing_like()
  end

  def validate_existing_like(%{changes: %{actor: actor, object: object}} = cng) do
    if Utils.get_existing_like(actor, %{data: %{"id" => object}}) do
      cng
      |> add_error(:actor, "already liked this object")
      |> add_error(:object, "already liked by this actor")
    else
      cng
    end
  end

  def validate_existing_like(cng), do: cng
end
