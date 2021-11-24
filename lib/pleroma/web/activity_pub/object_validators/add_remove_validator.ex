# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.AddRemoveValidator do
  use Ecto.Schema

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  require Pleroma.Constants

  alias Pleroma.User

  @primary_key false

  embedded_schema do
    field(:target)

    quote do
      unquote do
        import Elixir.Pleroma.Web.ActivityPub.ObjectValidators.CommonFields
        message_fields()
        activity_fields()
      end
    end
  end

  def cast_and_validate(data) do
    {:ok, actor} = User.get_or_fetch_by_ap_id(data["actor"])

    {:ok, actor} = maybe_refetch_user(actor)

    data
    |> maybe_fix_data_for_mastodon(actor)
    |> cast_data()
    |> validate_data(actor)
  end

  defp maybe_fix_data_for_mastodon(data, actor) do
    # Mastodon sends pin/unpin objects without id, to, cc fields
    data
    |> Map.put_new("id", Pleroma.Web.ActivityPub.Utils.generate_activity_id())
    |> Map.put_new("to", [Pleroma.Constants.as_public()])
    |> Map.put_new("cc", [actor.follower_address])
  end

  defp cast_data(data) do
    cast(%__MODULE__{}, data, __schema__(:fields))
  end

  defp validate_data(changeset, actor) do
    changeset
    |> validate_required([:id, :target, :object, :actor, :type, :to, :cc])
    |> validate_inclusion(:type, ~w(Add Remove))
    |> validate_actor_presence()
    |> validate_collection_belongs_to_actor(actor)
    |> validate_object_presence()
  end

  defp validate_collection_belongs_to_actor(changeset, actor) do
    validate_change(changeset, :target, fn :target, target ->
      if target == actor.featured_address do
        []
      else
        [target: "collection doesn't belong to actor"]
      end
    end)
  end

  defp maybe_refetch_user(%User{featured_address: address} = user) when is_binary(address) do
    {:ok, user}
  end

  defp maybe_refetch_user(%User{ap_id: ap_id}) do
    Pleroma.Web.ActivityPub.Transmogrifier.upgrade_user_from_ap_id(ap_id)
  end
end
