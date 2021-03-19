# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.AddRemoveValidator do
  use Ecto.Schema

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  require Pleroma.Constants

  alias Pleroma.EctoType.ActivityPub.ObjectValidators

  @primary_key false

  embedded_schema do
    field(:id, ObjectValidators.ObjectID, primary_key: true)
    field(:target)
    field(:object, ObjectValidators.ObjectID)
    field(:actor, ObjectValidators.ObjectID)
    field(:type)
    field(:to, ObjectValidators.Recipients, default: [])
    field(:cc, ObjectValidators.Recipients, default: [])
  end

  def cast_and_validate(data) do
    data
    |> maybe_fix_data_for_mastodon()
    |> cast_data()
    |> validate_data()
  end

  defp maybe_fix_data_for_mastodon(data) do
    {:ok, actor} = Pleroma.User.get_or_fetch_by_ap_id(data["actor"])
    # Mastodon sends pin/unpin objects without id, to, cc fields
    data
    |> Map.put_new("id", Pleroma.Web.ActivityPub.Utils.generate_activity_id())
    |> Map.put_new("to", [Pleroma.Constants.as_public()])
    |> Map.put_new("cc", [actor.follower_address])
  end

  defp cast_data(data) do
    cast(%__MODULE__{}, data, __schema__(:fields))
  end

  defp validate_data(changeset) do
    changeset
    |> validate_required([:id, :target, :object, :actor, :type, :to, :cc])
    |> validate_inclusion(:type, ~w(Add Remove))
    |> validate_actor_presence()
    |> validate_collection_belongs_to_actor()
    |> validate_object_presence()
  end

  defp validate_collection_belongs_to_actor(changeset) do
    {:ok, actor} = Pleroma.User.get_or_fetch_by_ap_id(changeset.changes[:actor])

    validate_change(changeset, :target, fn :target, target ->
      if target == actor.featured_address do
        []
      else
        [target: "collection doesn't belong to actor"]
      end
    end)
  end
end
