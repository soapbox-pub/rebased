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

  defp fix_activity_recipients(activity, field, object) do
    {:ok, data} = ObjectValidators.Recipients.cast(activity[field] || object[field])

    Map.put(activity, field, data)
  end

  def fix_activity_defaults(activity, meta) do
    object = meta[:object_data] || %{}

    activity
    |> fix_activity_recipients("to", object)
    |> fix_activity_recipients("cc", object)
    |> fix_activity_recipients("bto", object)
    |> fix_activity_recipients("bcc", object)
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
