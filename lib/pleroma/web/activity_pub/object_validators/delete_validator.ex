# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.DeleteValidator do
  use Ecto.Schema

  alias Pleroma.Activity
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ObjectValidators.Types

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  @primary_key false

  embedded_schema do
    field(:id, Types.ObjectID, primary_key: true)
    field(:type, :string)
    field(:actor, Types.ObjectID)
    field(:to, Types.Recipients, default: [])
    field(:cc, Types.Recipients, default: [])
    field(:deleted_activity_id, Types.ObjectID)
    field(:object, Types.ObjectID)
  end

  def cast_data(data) do
    %__MODULE__{}
    |> cast(data, __schema__(:fields))
  end

  def add_deleted_activity_id(cng) do
    object =
      cng
      |> get_field(:object)

    with %Activity{id: id} <- Activity.get_create_by_object_ap_id(object) do
      cng
      |> put_change(:deleted_activity_id, id)
    else
      _ -> cng
    end
  end

  @deletable_types ~w{
    Answer
    Article
    Audio
    Event
    Note
    Page
    Question
    Video
  }
  def validate_data(cng) do
    cng
    |> validate_required([:id, :type, :actor, :to, :cc, :object])
    |> validate_inclusion(:type, ["Delete"])
    |> validate_actor_presence()
    |> validate_deletion_rights()
    |> validate_object_or_user_presence(allowed_types: @deletable_types)
    |> add_deleted_activity_id()
  end

  def do_not_federate?(cng) do
    !same_domain?(cng)
  end

  defp same_domain?(cng) do
    actor_uri =
      cng
      |> get_field(:actor)
      |> URI.parse()

    object_uri =
      cng
      |> get_field(:object)
      |> URI.parse()

    object_uri.host == actor_uri.host
  end

  def validate_deletion_rights(cng) do
    actor = User.get_cached_by_ap_id(get_field(cng, :actor))

    if User.superuser?(actor) || same_domain?(cng) do
      cng
    else
      cng
      |> add_error(:actor, "is not allowed to delete object")
    end
  end

  def cast_and_validate(data) do
    data
    |> cast_data
    |> validate_data
  end
end
