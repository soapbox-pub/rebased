# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.CommonFixes do
  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Object.Containment
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.Utils

  def fix_object_defaults(data) do
    %{data: %{"id" => context}, id: context_id} =
      Utils.create_context(data["context"] || data["conversation"])

    %User{follower_address: follower_collection} = User.get_cached_by_ap_id(data["attributedTo"])
    {:ok, to} = ObjectValidators.Recipients.cast(data["to"] || [])
    {:ok, cc} = ObjectValidators.Recipients.cast(data["cc"] || [])

    data
    |> Map.put("context", context)
    |> Map.put("context_id", context_id)
    |> Map.put("to", to)
    |> Map.put("cc", cc)
    |> Transmogrifier.fix_explicit_addressing(follower_collection)
    |> Transmogrifier.fix_implicit_addressing(follower_collection)
  end

  def fix_activity_defaults(data, meta) do
    object = meta[:object_data] || %{}

    data
    |> Map.put_new("to", object["to"] || [])
    |> Map.put_new("cc", object["cc"] || [])
    |> Map.put_new("bto", object["bto"] || [])
    |> Map.put_new("bcc", object["bcc"] || [])
  end

  def fix_actor(data) do
    actor =
      data
      |> Map.put_new("actor", data["attributedTo"])
      |> Containment.get_actor()

    data
    |> Map.put("actor", actor)
    |> Map.put("attributedTo", actor)
  end
end
